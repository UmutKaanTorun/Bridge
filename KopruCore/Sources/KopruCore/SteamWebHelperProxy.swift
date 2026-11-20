import Foundation

/// Steam'in tarayıcı süreci (steamwebhelper) Wine'ın Mac sürücüsünde siyah pencere açıyor:
/// Chromium ayrı GPU sürecinden çiziyor, macdrv süreçler arası çizimi desteklemiyor.
/// Çözüm: gerçek dosyayı steamwebhelper_gercek.exe yapıp yerine onu --disable-gpu --single-process
/// ile açan aracıyı koymak. Steam güncellemesi aracıyı sildiğinde her açılışta yeniden yerleştirilir.
public enum SteamWebHelperProxy {
    public static let helperName = "steamwebhelper.exe"
    public static let realName = "steamwebhelper_gercek.exe"
    /// Aracı ~17 KB; gerçek dosya MB'larca. Bundan büyükse gerçek dosyadır.
    public static let realSizeThreshold = 500_000

    public static func cefDirectory(bottleURL: URL) -> URL {
        bottleURL.appendingPathComponent("drive_c/Program Files (x86)/Steam/bin/cef", isDirectory: true)
    }

    /// Bir şey değiştirdiyse true.
    @discardableResult
    public static func apply(bottleURL: URL, proxyExecutable: URL) throws -> Bool {
        let fm = FileManager.default
        let cef = cefDirectory(bottleURL: bottleURL)
        guard let children = try? fm.contentsOfDirectory(atPath: cef.path) else { return false }
        var changed = false
        for child in children.sorted() where child.hasPrefix("cef.win") {
            let dir = cef.appendingPathComponent(child, isDirectory: true)
            let helper = dir.appendingPathComponent(helperName)
            guard fm.fileExists(atPath: helper.path) else { continue }

            let size = (try fm.attributesOfItem(atPath: helper.path)[.size] as? NSNumber)?.intValue ?? 0
            if size > realSizeThreshold {
                let real = dir.appendingPathComponent(realName)
                if fm.fileExists(atPath: real.path) { try fm.removeItem(at: real) }
                try fm.moveItem(at: helper, to: real)
                changed = true
            }
            if !fm.contentsEqual(atPath: proxyExecutable.path, andPath: helper.path) {
                if fm.fileExists(atPath: helper.path) { try fm.removeItem(at: helper) }
                try fm.copyItem(at: proxyExecutable, to: helper)
                changed = true
            }
        }
        return changed
    }
}
