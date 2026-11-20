import Foundation

/// Steam'in tarayıcı süreci (steamwebhelper) Wine'ın Mac sürücüsünde siyah pencere açıyor:
/// Chromium ayrı GPU sürecinden çiziyor, macdrv süreçler arası çizimi desteklemiyor.
/// Çözüm: gerçek dosyayı steamwebhelper_gercek.exe yapıp yerine onu --disable-gpu --single-process
/// ile açan aracıyı koymak.
///
/// Steam açılışta dosya boyutlarını doğrular ("Verifying file sizes only") ve boyutu tutmayanları
/// paketten yeniden kurar. Bu yüzden aracı, gerçek dosyanın boyutuna kadar sıfırla doldurulur
/// (Windows ve Wine exe'nin sonundaki fazla veriyi yok sayar).
public enum SteamWebHelperProxy {
    public static let helperName = "steamwebhelper.exe"
    public static let realName = "steamwebhelper_gercek.exe"
    /// Aracının içinde geçen (UTF-16), gerçek Steam dosyasında olmayan metin; aracının her sürümünü tanır.
    public static let marker = Data("steamwebhelper_gercek.exe".utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
    /// Aracı ~17 KB; işaret ilk 64 KB'ta aranır.
    static let markerSearchLength = 64 * 1024

    public static func cefDirectory(bottleURL: URL) -> URL {
        bottleURL.appendingPathComponent("drive_c/Program Files (x86)/Steam/bin/cef", isDirectory: true)
    }

    /// Dosya Köprü'nün aracısı mı (dolgulu ya da dolgusuz, eski ya da yeni sürüm)?
    public static func isProxy(_ file: URL) -> Bool {
        guard let head = readHead(of: file, count: markerSearchLength) else { return false }
        return head.range(of: marker) != nil
    }

    /// Bir şey değiştirdiyse true. Bottle çalışırken saniyede bir çağrılır; ucuz kalmalı.
    @discardableResult
    public static func apply(bottleURL: URL, proxyExecutable: URL) throws -> Bool {
        let fm = FileManager.default
        let cef = cefDirectory(bottleURL: bottleURL)
        guard let children = try? fm.contentsOfDirectory(atPath: cef.path) else { return false }
        let proxy = try Data(contentsOf: proxyExecutable)
        var changed = false
        for child in children.sorted() where child.hasPrefix("cef.win") {
            let dir = cef.appendingPathComponent(child, isDirectory: true)
            let helper = dir.appendingPathComponent(helperName)
            let real = dir.appendingPathComponent(realName)
            guard fm.fileExists(atPath: helper.path) else { continue }

            if !isProxy(helper) {
                // Steam yeni bir gerçek dosya yazmış (kurulum ya da güncelleme): kenara al.
                if fm.fileExists(atPath: real.path) { try fm.removeItem(at: real) }
                try fm.moveItem(at: helper, to: real)
                changed = true
            }

            let size = max(proxy.count, fileSize(real) ?? proxy.count)
            if fileSize(helper) != size || readHead(of: helper, count: proxy.count) != proxy {
                var padded = proxy
                padded.append(Data(count: size - proxy.count))
                try padded.write(to: helper, options: .atomic)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
                changed = true
            }
        }
        return changed
    }

    private static func fileSize(_ file: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue
    }

    private static func readHead(of file: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: count)
    }
}
