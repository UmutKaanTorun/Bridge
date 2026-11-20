import Foundation

/// Köprü'nün diskteki klasörleri. Testler geçici bir kök verir.
public struct KopruPaths: Sendable, Equatable {
    /// ~/Library/Application Support/Kopru
    public let applicationSupport: URL
    /// ~/Library/Logs/Kopru
    public let logs: URL

    public init(applicationSupport: URL, logs: URL) {
        self.applicationSupport = applicationSupport
        self.logs = logs
    }

    public static var standard: KopruPaths {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return KopruPaths(
            applicationSupport: library.appendingPathComponent("Application Support/Kopru", isDirectory: true),
            logs: library.appendingPathComponent("Logs/Kopru", isDirectory: true)
        )
    }

    /// Her alt klasör bir Wine bottle'ı (WINEPREFIX).
    public var bottles: URL { applicationSupport.appendingPathComponent("Bottles", isDirectory: true) }

    /// İndirilen kurulum dosyaları.
    public var downloads: URL { applicationSupport.appendingPathComponent("Downloads", isDirectory: true) }

    public func logFile(forBottleFolder folder: String) -> URL {
        logs.appendingPathComponent("\(folder).log")
    }
}
