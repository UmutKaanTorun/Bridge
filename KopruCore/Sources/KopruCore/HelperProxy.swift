import Foundation

/// Bottle'daki bir yardımcı programı (ör. Social Club'ın CEF tarayıcısı SocialClubHelper.exe) Köprü'nün
/// aracısıyla değiştirir: gerçek dosya `<ad>_gercek.exe` olur, aracı onu ek Chromium bayraklarıyla açar
/// (Tools/cef-araci). Program yardımcıyı kendi sabit argümanlarıyla açtığında bayrak vermenin tek yolu bu.
///
/// Neden: Wine'ın Mac sürücüsünde (ve DXMT'de) Chromium'un ayrı GPU süreci, tarayıcı sürecinin penceresine
/// çizemiyor (`cross-process swapchain not supported`); pencere boş kalıyor. `--in-process-gpu` GPU'yu
/// tarayıcı sürecine alıyor. Steam'in aynı işi yapan, dosya boyutu doğrulamasına göre dolgulanan
/// karşılığı: `SteamWebHelperProxy`.
public enum HelperProxy {
    /// Aracı ~17 KB; işaret ilk 64 KB'ta aranır.
    static let markerSearchLength = 64 * 1024

    /// "SocialClubHelper.exe" → "SocialClubHelper_gercek.exe"
    public static func realName(forHelperNamed name: String) -> String {
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        return ext.isEmpty ? base + "_gercek" : "\(base)_gercek.\(ext)"
    }

    /// Aracının içinde geçen gerçek dosya adı (UTF-16); gerçek programda bulunmaz, aracının her sürümünü tanır.
    public static func marker(forHelperNamed name: String) -> Data {
        Data(realName(forHelperNamed: name).utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
    }

    public static func isProxy(_ file: URL, helperNamed name: String) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: markerSearchLength) else { return false }
        return head.range(of: marker(forHelperNamed: name)) != nil
    }

    /// Yardımcı yoksa (program henüz kurmamış) bir şey yapmaz. Bir şey değiştirdiyse true.
    /// Program çalışırken saniyede bir çağrılabilir; ucuz kalmalı.
    @discardableResult
    public static func apply(helper: URL, proxyExecutable: URL) throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: helper.path) else { return false }
        let name = helper.lastPathComponent
        let real = helper.deletingLastPathComponent().appendingPathComponent(realName(forHelperNamed: name))
        var changed = false
        if !isProxy(helper, helperNamed: name) {
            // Program yeni bir gerçek dosya yazmış (kurulum ya da güncelleme): kenara al.
            if fm.fileExists(atPath: real.path) { try fm.removeItem(at: real) }
            try fm.moveItem(at: helper, to: real)
            changed = true
        }
        let proxy = try Data(contentsOf: proxyExecutable)
        if changed || (try? Data(contentsOf: helper)) != proxy {
            try proxy.write(to: helper, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
            changed = true
        }
        return changed
    }
}
