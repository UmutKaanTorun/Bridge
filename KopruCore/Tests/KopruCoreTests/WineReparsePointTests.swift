import Darwin
import Foundation
import Testing
@testable import KopruCore

/// Wine'ın Windows bağlantılarını Mac tarafında sakladığı biçim: `<ad>?` + `user.WINEREPARSE` ek özniteliği.
struct WineReparsePointTests {
    /// REPARSE_DATA_BUFFER: sembolik bağlantı (göreli ya da mutlak) ya da bağlantı noktası (junction).
    private func reparseData(target: String, junction: Bool = false, relative: Bool = false) -> Data {
        let name = Data(target.utf16.flatMap { [UInt8($0 & 0xff), UInt8($0 >> 8)] })
        var data = Data()
        func u16(_ value: Int) { data.append(contentsOf: [UInt8(value & 0xff), UInt8(value >> 8)]) }
        func u32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let header = junction ? 8 : 12
        u32(junction ? 0xA000_0003 : 0xA000_000C)
        u16(header + 2 * name.count + 4)
        u16(0)
        u16(0); u16(name.count)                 // SubstituteName
        u16(name.count + 2); u16(name.count)    // PrintName
        if !junction { u32(relative ? 1 : 0) }
        data.append(name); u16(0)
        data.append(name); u16(0)
        return data
    }

    private func makeReparsePoint(_ td: TempDir, _ relative: String, data: Data) throws {
        let marker = try td.dir(relative + "?")
        let result = data.withUnsafeBytes { setxattr(marker.path, "user.WINEREPARSE", $0.baseAddress, data.count, 0, 0) }
        #expect(result == 0)
    }

    /// EA App: `EA Desktop\EA Desktop` → `13.832.0.6345\EA Desktop` (göreli dizin bağlantısı).
    @Test func followsRelativeSymlink() throws {
        let td = try TempDir()
        try td.file("drive_c/Program Files/EA/13.832/EA Desktop/EADesktop.exe")
        try makeReparsePoint(td, "drive_c/Program Files/EA/EA Desktop",
                             data: reparseData(target: "13.832\\EA Desktop", relative: true))
        let recipe = Recipe.fixture(detect: ["drive_c/Program Files/EA/EA Desktop/EADesktop.exe"])
        #expect(recipe.isInstalled(in: td.url))
        #expect(WineReparsePoint.resolve("drive_c/Program Files/EA/EA Desktop/EADesktop.exe", in: td.url)?.path
                == td.url.appendingPathComponent("drive_c/Program Files/EA/13.832/EA Desktop/EADesktop.exe").path)
    }

    @Test func followsAbsoluteJunctionThroughDosDevices() throws {
        let td = try TempDir()
        try td.file("drive_c/Gercek/Uygulama.exe")
        try td.dir("dosdevices")
        try FileManager.default.createSymbolicLink(atPath: td.url.appendingPathComponent("dosdevices/c:").path,
                                                   withDestinationPath: "../drive_c")
        try makeReparsePoint(td, "drive_c/Kisayol", data: reparseData(target: "\\??\\C:\\Gercek", junction: true))
        #expect(Recipe.fixture(detect: ["drive_c/Kisayol/Uygulama.exe"]).isInstalled(in: td.url))
    }

    @Test func missingTargetOrPlainMarkerIsNotInstalled() throws {
        let td = try TempDir()
        try makeReparsePoint(td, "drive_c/Bos", data: reparseData(target: "Yok", relative: true))
        try td.dir("drive_c/Ozniteliksiz?")
        #expect(!Recipe.fixture(detect: ["drive_c/Bos/a.exe"]).isInstalled(in: td.url))
        #expect(!Recipe.fixture(detect: ["drive_c/Ozniteliksiz/a.exe"]).isInstalled(in: td.url))
    }

    @Test func loopsAndEscapesStop() throws {
        let td = try TempDir()
        try makeReparsePoint(td, "drive_c/A", data: reparseData(target: "B", relative: true))
        try makeReparsePoint(td, "drive_c/B", data: reparseData(target: "A", relative: true))
        try makeReparsePoint(td, "drive_c/Dis", data: reparseData(target: "..\\..\\..", relative: true))
        #expect(WineReparsePoint.resolve("drive_c/A/a.exe", in: td.url) == nil)
        #expect(WineReparsePoint.resolve("drive_c/Dis/etc/hosts", in: td.url) == nil)
    }
}
