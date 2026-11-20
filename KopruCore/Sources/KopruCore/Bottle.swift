import Foundation

/// Bir Wine bottle'ı: klasörün kendisi WINEPREFIX, içinde kopru.json.
public struct Bottle: Identifiable, Hashable, Sendable {
    public let url: URL
    public var info: BottleInfo

    public init(url: URL, info: BottleInfo) {
        self.url = url
        self.info = info
    }

    /// Klasör adı benzersizdir; kimlik olarak kullanılır.
    public var id: String { url.lastPathComponent }
    public var folderName: String { url.lastPathComponent }
    public var driveC: URL { url.appendingPathComponent("drive_c", isDirectory: true) }
}
