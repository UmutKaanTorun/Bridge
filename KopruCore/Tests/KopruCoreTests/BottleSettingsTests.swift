import Foundation
import Testing
@testable import KopruCore

struct BottleSettingsTests {
    @Test func oldKopruJSONDecodesWithoutPerformanceFields() throws {
        // Bu Mac'teki Steam bottle'ının kopru.json'undaki ayarlar; virtualDesktop artık yok sayılıyor.
        let json = #"{"fpsHud":false,"msync":true,"virtualDesktop":{"mode":"auto"}}"#
        let settings = try JSONDecoder().decode(BottleSettings.self, from: Data(json.utf8))
        #expect(settings == BottleSettings(msync: true, fpsHud: false))
        #expect(settings.metalFXUpscale == nil)
        #expect(settings.advertiseAVX == nil)
    }

    @Test func performanceFieldsRoundTrip() throws {
        let settings = BottleSettings(metalFXUpscale: true, advertiseAVX: false)
        let decoded = try JSONDecoder().decode(BottleSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        #expect(decoded.metalFXUpscale == true)
        #expect(decoded.advertiseAVX == false)
    }

    @Test func restartIsRequiredOnlyForMSyncAndAVX() {
        let old = BottleSettings()
        #expect(BottleSettings(msync: false).requiresRestart(comparedTo: old))
        #expect(BottleSettings(advertiseAVX: true).requiresRestart(comparedTo: old))
        // nil ile false aynı: eski kopru.json'u kaydetmek bottle'ı durdurmaz.
        #expect(!BottleSettings(advertiseAVX: false).requiresRestart(comparedTo: old))
        #expect(!BottleSettings(fpsHud: true, metalFXUpscale: true).requiresRestart(comparedTo: old))
    }
}
