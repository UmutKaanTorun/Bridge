import Foundation
import Testing
@testable import KopruCore

/// Uygulamayla dağıtılan derlenmiş Steam aracısı (Resources/RecipeFiles/steam/steamwebhelper.exe).
struct ProxyBinaryTests {
    static let proxy = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // KopruCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // KopruCore
        .deletingLastPathComponent()   // depo kökü
        .appendingPathComponent("Resources/RecipeFiles/steam/steamwebhelper.exe")

    /// PE başlığındaki alt sistem: 2 = Windows GUI, 3 = konsol.
    static func subsystem(of data: Data) -> UInt16? {
        guard data.count > 0x40 else { return nil }
        let peOffset = Int(data[0x3C]) | Int(data[0x3D]) << 8 | Int(data[0x3E]) << 16 | Int(data[0x3F]) << 24
        let field = peOffset + 4 + 20 + 68   // imza + COFF başlığı + isteğe bağlı başlıkta Subsystem
        guard data.count > field + 1, data[peOffset..<peOffset + 4] == Data("PE\0\0".utf8) else { return nil }
        return UInt16(data[field]) | UInt16(data[field + 1]) << 8
    }

    /// Konsol programı olursa Wine, Köprü'den açılınca aracıya siyah bir konsol penceresi açar.
    @Test func proxyIsAWindowsGUIProgram() throws {
        #expect(Self.subsystem(of: try Data(contentsOf: Self.proxy)) == 2)
    }

    @Test func proxyCarriesTheMarker() {
        #expect(SteamWebHelperProxy.isProxy(Self.proxy))
    }
}
