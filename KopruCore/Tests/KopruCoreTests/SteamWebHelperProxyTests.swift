import Foundation
import Testing
@testable import KopruCore

struct SteamWebHelperProxyTests {
    static let cef = "bottle/drive_c/Program Files (x86)/Steam/bin/cef"

    private func proxy(_ td: TempDir) throws -> URL {
        try td.file("RecipeFiles/steam/steamwebhelper.exe", "ARACI")
    }

    @Test func replacesRealHelperWithProxy() throws {
        let td = try TempDir()
        let real = Data(repeating: 0x4D, count: 600_000)
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", data: real)
        try td.dir("\(Self.cef)/cef.win7")   // aracısı olmayan klasör atlanır
        let bottle = td.url.appendingPathComponent("bottle")

        #expect(try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: try proxy(td)))

        let dir = td.url.appendingPathComponent("\(Self.cef)/cef.win64")
        #expect(try Data(contentsOf: dir.appendingPathComponent("steamwebhelper_gercek.exe")) == real)
        #expect(try String(contentsOf: dir.appendingPathComponent("steamwebhelper.exe"), encoding: .utf8) == "ARACI")
        #expect(!FileManager.default.fileExists(atPath: td.url.appendingPathComponent("\(Self.cef)/cef.win7/steamwebhelper.exe").path))
    }

    @Test func secondRunChangesNothing() throws {
        let td = try TempDir()
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", data: Data(repeating: 1, count: 600_000))
        let bottle = td.url.appendingPathComponent("bottle")
        let proxyFile = try proxy(td)
        try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: proxyFile)
        #expect(try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: proxyFile) == false)
    }

    @Test func smallForeignHelperIsReplacedButRealKept() throws {
        let td = try TempDir()
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", "ESKI ARACI")
        try td.file("\(Self.cef)/cef.win64/steamwebhelper_gercek.exe", "GERCEK")
        let bottle = td.url.appendingPathComponent("bottle")
        #expect(try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: try proxy(td)))
        let dir = td.url.appendingPathComponent("\(Self.cef)/cef.win64")
        #expect(try String(contentsOf: dir.appendingPathComponent("steamwebhelper.exe"), encoding: .utf8) == "ARACI")
        #expect(try String(contentsOf: dir.appendingPathComponent("steamwebhelper_gercek.exe"), encoding: .utf8) == "GERCEK")
    }

    @Test func noSteamNoChange() throws {
        let td = try TempDir()
        #expect(try SteamWebHelperProxy.apply(bottleURL: try td.dir("bottle"), proxyExecutable: try proxy(td)) == false)
    }
}
