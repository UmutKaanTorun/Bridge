import Foundation
import Testing
@testable import KopruCore

struct BottleSettingsTests {
    @Test func autoDesktopIsScreenMinus40() {
        let size = VirtualDesktop.auto.size(visibleScreen: PixelSize(width: 1512, height: 944))
        #expect(size == PixelSize(width: 1472, height: 904))
    }

    @Test func offDesktopHasNoSize() {
        #expect(VirtualDesktop.off.size(visibleScreen: PixelSize(width: 1512, height: 944)) == nil)
    }

    @Test func fixedDesktopKeepsItsSize() {
        let size = VirtualDesktop.fixed(width: 1280, height: 800).size(visibleScreen: PixelSize(width: 1512, height: 944))
        #expect(size == PixelSize(width: 1280, height: 800))
    }

    @Test func decodesDesktopModes() throws {
        let decoder = JSONDecoder()
        #expect(try decoder.decode(VirtualDesktop.self, from: Data(#"{"mode":"auto"}"#.utf8)) == .auto)
        #expect(try decoder.decode(VirtualDesktop.self, from: Data(#"{"mode":"off"}"#.utf8)) == .off)
        #expect(try decoder.decode(VirtualDesktop.self, from: Data(#"{"mode":"fixed","width":1280,"height":800}"#.utf8))
                == .fixed(width: 1280, height: 800))
        #expect(throws: DecodingError.self) {
            try decoder.decode(VirtualDesktop.self, from: Data(#"{"mode":"yan"}"#.utf8))
        }
    }

    @Test func settingsRoundTrip() throws {
        let settings = BottleSettings(msync: false, virtualDesktop: .fixed(width: 1024, height: 768), fpsHud: true)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(BottleSettings.self, from: data) == settings)
    }

    @Test func defaultSettings() {
        #expect(BottleSettings.default == BottleSettings(msync: true, virtualDesktop: .off, fpsHud: false))
        #expect(BottleSettings.default.wined3dPrograms == nil)
    }

    @Test func wined3dProgramsRoundTrip() throws {
        let settings = BottleSettings(msync: true, virtualDesktop: .auto, fpsHud: false, wined3dPrograms: ["Launcher.exe"])
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(BottleSettings.self, from: data) == settings)
    }

    @Test func settingsWithoutWined3dProgramsStillDecode() throws {
        // Eski kopru.json dosyalarında bu alan yok.
        let json = #"{"msync":true,"virtualDesktop":{"mode":"off"},"fpsHud":false}"#
        let settings = try JSONDecoder().decode(BottleSettings.self, from: Data(json.utf8))
        #expect(settings == .default)
        #expect(settings.wined3dPrograms == nil)
    }
}
