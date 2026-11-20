import Foundation
@testable import KopruCore

/// Test başına geçici klasör; nesne bırakılınca silinir.
final class TempDir: @unchecked Sendable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("KopruTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    /// Göreli yolda (ara klasörleriyle) metin dosyası oluşturur.
    @discardableResult
    func file(_ relative: String, _ contents: String = "") throws -> URL {
        try file(relative, data: Data(contents.utf8))
    }

    @discardableResult
    func file(_ relative: String, data: Data) throws -> URL {
        let target = url.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target)
        return target
    }

    @discardableResult
    func dir(_ relative: String) throws -> URL {
        let target = url.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    /// Bu klasörün altındaki Köprü yolları.
    var paths: KopruPaths {
        KopruPaths(applicationSupport: url.appendingPathComponent("AppSupport", isDirectory: true),
                   logs: url.appendingPathComponent("Logs", isDirectory: true))
    }
}
