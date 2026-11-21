import Foundation
import Testing
@testable import KopruCore

struct BottleSettingsTests {
    @Test func settingsRoundTrip() throws {
        let settings = BottleSettings(msync: false, fpsHud: true)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(BottleSettings.self, from: data) == settings)
    }

    @Test func defaultSettings() {
        #expect(BottleSettings.default == BottleSettings(msync: true, fpsHud: false))
        #expect(BottleSettings.default.wined3dPrograms == nil)
    }

    @Test func wined3dProgramsRoundTrip() throws {
        let settings = BottleSettings(msync: true, fpsHud: false, wined3dPrograms: ["Launcher.exe"])
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(BottleSettings.self, from: data) == settings)
    }

    @Test func settingsWithoutWined3dProgramsStillDecode() throws {
        // Eski kopru.json dosyalarında bu alan yok.
        let json = #"{"msync":true,"fpsHud":false}"#
        let settings = try JSONDecoder().decode(BottleSettings.self, from: Data(json.utf8))
        #expect(settings == .default)
        #expect(settings.wined3dPrograms == nil)
    }

    /// Sanal masaüstü kaldırıldı: Wine'ın Mac sürücüsünde yok (explorer /desktop tek pencere açmıyor, boyut da
    /// uygulanmıyor), yalnız yan etkileri kalıyordu. Eski kopru.json'lardaki alan okunurken yok sayılır.
    @Test func legacyVirtualDesktopIsIgnored() throws {
        for mode in [#"{"mode":"auto"}"#, #"{"mode":"off"}"#, #"{"mode":"fixed","width":1280,"height":800}"#] {
            let json = #"{"msync":true,"virtualDesktop":\#(mode),"fpsHud":false}"#
            #expect(try JSONDecoder().decode(BottleSettings.self, from: Data(json.utf8)) == .default)
        }
        let encoded = String(decoding: try JSONEncoder().encode(BottleSettings.default), as: UTF8.self)
        #expect(!encoded.contains("virtualDesktop"))
    }
}
