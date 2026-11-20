import Foundation
import Testing
@testable import KopruCore

struct DownloaderTests {
    static let abcSHA = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    @Test func hashesFile() throws {
        let td = try TempDir()
        #expect(try Downloader.sha256(of: try td.file("abc.txt", "abc")) == Self.abcSHA)
    }

    @Test func downloadsAndReportsProgress() async throws {
        let td = try TempDir()
        let source = try td.file("kaynak/SteamSetup.exe", "abc")
        let destination = td.url.appendingPathComponent("Downloads/SteamSetup.exe")
        let progress = Collected<Double>()
        try await Downloader().download(source, to: destination, sha256: Self.abcSHA.uppercased()) { progress.add($0) }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "abc")
        #expect(progress.all.last == 1)
    }

    @Test func checksumMismatchDeletesFile() async throws {
        let td = try TempDir()
        let source = try td.file("kaynak/a.exe", "abc")
        let destination = td.url.appendingPathComponent("Downloads/a.exe")
        await #expect(throws: DownloadError.checksumMismatch(expected: String(repeating: "0", count: 64), actual: Self.abcSHA)) {
            try await Downloader().download(source, to: destination, sha256: String(repeating: "0", count: 64)) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func validCachedFileIsNotDownloadedAgain() async throws {
        let td = try TempDir()
        let destination = try td.file("Downloads/a.exe", "abc")
        let missing = td.url.appendingPathComponent("olmayan.exe")
        try await Downloader().download(missing, to: destination, sha256: Self.abcSHA) { _ in }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "abc")
    }

    @Test func missingSourceThrows() async throws {
        let td = try TempDir()
        await #expect(throws: (any Error).self) {
            try await Downloader().download(td.url.appendingPathComponent("olmayan.exe"),
                                            to: td.url.appendingPathComponent("Downloads/x.exe"), sha256: nil) { _ in }
        }
    }

    @Test func tlsErrorsBecomeInsecureNetwork() {
        #expect(Downloader.map(URLError(.serverCertificateUntrusted)) as? DownloadError == .insecureNetwork)
        #expect(Downloader.map(URLError(.serverCertificateHasUnknownRoot)) as? DownloadError == .insecureNetwork)
        #expect(Downloader.map(URLError(.secureConnectionFailed)) as? DownloadError == .insecureNetwork)
        #expect((Downloader.map(URLError(.timedOut)) as? URLError)?.code == .timedOut)
    }
}
