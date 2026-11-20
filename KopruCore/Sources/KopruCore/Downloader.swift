import CryptoKit
import Foundation

public enum DownloadError: Error, Equatable, LocalizedError {
    case insecureNetwork
    case httpStatus(Int)
    case checksumMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .insecureNetwork:
            "Ağ bağlantısı sunucuya güvenli şekilde ulaşamıyor. Kurum ağındaysan güvenlik duvarı engelliyor olabilir; başka bir ağda dene."
        case let .httpStatus(code):
            "Sunucu dosyayı vermedi (HTTP \(code))."
        case .checksumMismatch:
            "İndirilen dosya beklenen dosya değil (SHA-256 tutmadı); dosya silindi."
        }
    }
}

/// Kurulum dosyalarını indirir.
public struct Downloader: Sendable {
    public init() {}

    /// `source`'u `destination`'a indirir. `sha256` verilmişse doğrular ve hedefte doğru dosya
    /// zaten varsa tekrar indirmez.
    public func download(_ source: URL, to destination: URL, sha256: String?,
                         progress: @escaping @Sendable (Double) -> Void) async throws {
        let fm = FileManager.default
        let expected = sha256?.lowercased()
        if let expected, fm.fileExists(atPath: destination.path), (try? Self.sha256(of: destination)) == expected {
            progress(1)
            return
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await fetch(source, to: destination, progress: progress)
        if let expected {
            let actual = try Self.sha256(of: destination)
            guard actual == expected else {
                try? fm.removeItem(at: destination)
                throw DownloadError.checksumMismatch(expected: expected, actual: actual)
            }
        }
        progress(1)
    }

    private func fetch(_ source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let box = ObservationBox()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let task = URLSession.shared.downloadTask(with: source) { temporary, response, error in
                box.invalidate()
                if let error {
                    continuation.resume(throwing: Self.map(error))
                    return
                }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    continuation.resume(throwing: DownloadError.httpStatus(http.statusCode))
                    return
                }
                guard let temporary else {
                    continuation.resume(throwing: URLError(.unknown))
                    return
                }
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
                    try fm.moveItem(at: temporary, to: destination)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            box.set(task.progress.observe(\.fractionCompleted) { value, _ in progress(value.fractionCompleted) })
            task.resume()
        }
    }

    /// Sertifika/TLS hataları (ör. kurum güvenlik duvarının TLS denetimi) → `insecureNetwork`.
    public static func map(_ error: any Error) -> any Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .secureConnectionFailed, .clientCertificateRejected, .clientCertificateRequired:
            return DownloadError.insecureNetwork
        default:
            return error
        }
    }

    public static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// İlerleme gözlemcisini indirme bitene kadar canlı tutar.
private final class ObservationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var observation: NSKeyValueObservation?

    func set(_ observation: NSKeyValueObservation) { lock.withLock { self.observation = observation } }

    func invalidate() {
        lock.withLock {
            observation?.invalidate()
            observation = nil
        }
    }
}
