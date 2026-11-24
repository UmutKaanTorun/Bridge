import Foundation
import Testing
@testable import KopruCore

struct WineRegistryFileTests {
    /// Wine'ın yazdığı biçim: anahtar yolunda ve dizgilerde `\` ikilenir, dizgide `"` kaçışlanır.
    static let userReg = #"""
    WINE REGISTRY Version 2
    ;; All keys relative to REGISTRY\\User\\S-1-5-21-0-0-0-1000

    #arch=win64

    [Software\\Wine\\AppDefaults\\Steam.exe\\Mac Driver] 1795193701
    #time=1dd790fe1e216c2
    "ShowInDock"="n"

    [Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver2] 1795193701
    #time=1dd790fe1e216c2
    "Other"="n"

    [Software\\Wine\\DllOverrides] 1795193724
    #time=1dd790feff25510
    "gameoverlayrenderer64"=""
    "Yol"="C:\\Program Files\\\"x\""

    """#

    private func contains(_ key: String, _ name: String, _ value: String, file: String? = userReg) throws -> Bool {
        let td = try TempDir()
        if let file { try td.file("user.reg", file) }
        return WineRegistryFile.containsUserString(key: key, name: name, value: value, inBottleAt: td.url)
    }

    /// Kayıt defteri adları büyük-küçük harf ayırmaz; Wine anahtarı ilk yazıldığı biçimde saklar.
    @Test func findsValueIgnoringCaseOfKeyAndName() throws {
        #expect(try contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver", "ShowInDock", "n"))
        #expect(try contains("HKEY_CURRENT_USER\\software\\wine\\appdefaults\\STEAM.EXE\\mac driver", "showindock", "n"))
    }

    @Test func findsEmptyAndEscapedStrings() throws {
        #expect(try contains("HKCU\\Software\\Wine\\DllOverrides", "gameoverlayrenderer64", ""))
        #expect(try contains("HKCU\\Software\\Wine\\DllOverrides", "Yol", "C:\\Program Files\\\"x\""))
    }

    @Test func valueMustMatchExactly() throws {
        #expect(try !contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver", "ShowInDock", "N"))
        #expect(try !contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver", "ShowInDock", "y"))
    }

    /// Değer başka anahtarda (adı aranan anahtarla başlayan kardeş anahtar dahil) varsa sayılmaz.
    @Test func valueMustBeUnderTheKey() throws {
        #expect(try !contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver", "Other", "n"))
        #expect(try !contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver2", "ShowInDock", "n"))
        #expect(try !contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe", "ShowInDock", "n"))
    }

    /// Yalnız user.reg okunur; öteki kökler ve okunamayan dosya "bilinmiyor" (yazılmamış) sayılır.
    @Test func unknownWhenNotReadable() throws {
        #expect(try !contains("HKLM\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver", "ShowInDock", "n"))
        #expect(try !contains("HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver", "ShowInDock", "n", file: nil))
    }
}
