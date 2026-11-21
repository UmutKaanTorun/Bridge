import Darwin
import Foundation

/// Windows programlarının açtığı sembolik bağlantılar ve bağlantı noktaları (junction). Wine bunları Mac tarafında
/// `<ad>?` adlı boş bir girdi olarak saklar; hedef, girdinin `user.WINEREPARSE` ek özniteliğindeki
/// REPARSE_DATA_BUFFER'dadır (dlls/ntdll/unix/file.c). Wine'ın içinden yol çözülür, Mac'ten bakan bulamaz:
/// EA App `EA Desktop\EA Desktop`'u sürüm klasörüne (`13.832.0.6345\EA Desktop`) böyle bağlar.
public enum WineReparsePoint {
    enum Target: Equatable {
        /// Bağlantının bulunduğu klasöre göre.
        case relative([String])
        /// `\??\C:\…`: sürücü harfi (küçük) ve kökten sonraki parçalar.
        case absolute(drive: Character, [String])
    }

    static let attribute = "user.WINEREPARSE"
    private static let maxHops = 8
    private static let symlinkTag: UInt32 = 0xA000_000C
    private static let mountPointTag: UInt32 = 0xA000_0003

    /// Bottle'a göre göreli, `/` ayrılmış yolu Wine bağlantılarını izleyerek çözer. Yol yoksa, bottle'ın dışına
    /// çıkıyorsa ya da bağlantılar döngüye giriyorsa nil.
    public static func resolve(_ relativePath: String, in bottleURL: URL) -> URL? {
        let direct = bottleURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }

        var pending = relativePath.split(separator: "/").map(String.init)
        var resolved: [String] = []
        // Mutlak hedeften sonra `..` sürücü kökünde durur (Windows'taki gibi); bottle kökünde ise reddedilir.
        var floor = 0
        var hops = 0
        while !pending.isEmpty {
            let component = pending.removeFirst()
            if component.isEmpty || component == "." { continue }
            if component == ".." {
                if resolved.count > floor { resolved.removeLast() } else if floor == 0 { return nil }
                continue
            }
            if FileManager.default.fileExists(atPath: url(bottleURL, resolved + [component]).path) {
                resolved.append(component)
                continue
            }
            hops += 1
            guard hops <= maxHops, let target = target(of: url(bottleURL, resolved + [component + "?"])) else { return nil }
            switch target {
            case let .relative(parts):
                pending = parts + pending
            case let .absolute(drive, parts):
                resolved = ["dosdevices", "\(drive):"]
                floor = 2
                pending = parts + pending
            }
        }
        let result = url(bottleURL, resolved)
        return FileManager.default.fileExists(atPath: result.path) ? result : nil
    }

    /// Wine'ın bağlantı girdisindeki hedef; öznitelik yoksa ya da tanınmayan bir türse nil.
    static func target(of marker: URL) -> Target? {
        let size = getxattr(marker.path, attribute, nil, 0, 0, 0)
        guard size >= 16 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard getxattr(marker.path, attribute, &bytes, size, 0, 0) == size else { return nil }
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func u32(_ offset: Int) -> UInt32 { UInt32(u16(offset)) | UInt32(u16(offset + 2)) << 16 }

        let pathBuffer: Int
        var isRelative = false
        switch u32(0) {
        case symlinkTag:
            guard size >= 20 else { return nil }
            pathBuffer = 20
            isRelative = u32(16) & 1 != 0  // SYMLINK_FLAG_RELATIVE
        case mountPointTag:
            pathBuffer = 16
        default:
            return nil
        }
        let start = pathBuffer + u16(8), length = u16(10)  // SubstituteName
        guard length > 0, length % 2 == 0, start + length <= size else { return nil }
        let units = stride(from: start, to: start + length, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8 }
        let name = String(decoding: units, as: UTF16.self)
        if isRelative { return .relative(name.split(separator: "\\").map(String.init)) }

        var path = Substring(name)
        if path.hasPrefix("\\??\\") { path = path.dropFirst(4) }
        guard let drive = path.first, drive.isASCII, drive.isLetter, path.dropFirst().first == ":" else { return nil }
        return .absolute(drive: Character(drive.lowercased()), path.dropFirst(2).split(separator: "\\").map(String.init))
    }

    private static func url(_ base: URL, _ components: [String]) -> URL {
        components.reduce(base) { $0.appendingPathComponent($1) }
    }
}
