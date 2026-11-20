import Foundation
import Testing
@testable import KopruCore

/// Aracının içinde, gerçek Steam dosyasında olmayan "steamwebhelper_gercek.exe" metni (UTF-16) bulunur.
func proxyFixture(_ label: String = "ARACI") -> Data {
    Data(label.utf8) + SteamWebHelperProxy.marker
}

/// Dosya aracının dolgulu kopyası mı: başı aracıyla aynı, boyutu beklenen.
func isPaddedProxy(_ file: URL, proxy: Data, size: Int) -> Bool {
    guard let data = try? Data(contentsOf: file) else { return false }
    return data.count == size && data.prefix(proxy.count) == proxy && data.dropFirst(proxy.count).allSatisfy { $0 == 0 }
}

struct SteamWebHelperProxyTests {
    static let cef = "bottle/drive_c/Program Files (x86)/Steam/bin/cef"

    private func proxy(_ td: TempDir, _ data: Data = proxyFixture()) throws -> URL {
        try td.file("RecipeFiles/steam/steamwebhelper.exe", data: data)
    }

    @Test func recognisesAnyProxyVersionByMarker() throws {
        let td = try TempDir()
        #expect(SteamWebHelperProxy.isProxy(try td.file("a.exe", data: proxyFixture("ESKI SURUM"))))
        #expect(!SteamWebHelperProxy.isProxy(try td.file("b.exe", data: Data(repeating: 0x4D, count: 600_000))))
        #expect(!SteamWebHelperProxy.isProxy(td.url.appendingPathComponent("olmayan.exe")))
    }

    /// Steam dosya boyutlarını doğruluyor; aracı gerçek dosyanın boyutuna kadar sıfırla doldurulur.
    @Test func replacesRealHelperWithPaddedProxy() throws {
        let td = try TempDir()
        let real = Data(repeating: 0x4D, count: 600_000)
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", data: real)
        try td.dir("\(Self.cef)/cef.win7")   // aracısı olmayan klasör atlanır
        let bottle = td.url.appendingPathComponent("bottle")

        #expect(try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: try proxy(td)))

        let dir = td.url.appendingPathComponent("\(Self.cef)/cef.win64")
        #expect(try Data(contentsOf: dir.appendingPathComponent("steamwebhelper_gercek.exe")) == real)
        #expect(isPaddedProxy(dir.appendingPathComponent("steamwebhelper.exe"), proxy: proxyFixture(), size: 600_000))
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

    /// Faz 0'daki ya da eski Köprü sürümündeki dolgusuz aracı gerçek dosya sanılmamalı (yoksa gerçek dosyanın üzerine yazılır).
    @Test func oldProxyIsUpgradedAndRealKept() throws {
        let td = try TempDir()
        let real = Data(repeating: 7, count: 700_000)
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", data: proxyFixture("ESKI ARACI"))
        try td.file("\(Self.cef)/cef.win64/steamwebhelper_gercek.exe", data: real)
        let bottle = td.url.appendingPathComponent("bottle")
        #expect(try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: try proxy(td)))
        let dir = td.url.appendingPathComponent("\(Self.cef)/cef.win64")
        #expect(try Data(contentsOf: dir.appendingPathComponent("steamwebhelper_gercek.exe")) == real)
        #expect(isPaddedProxy(dir.appendingPathComponent("steamwebhelper.exe"), proxy: proxyFixture(), size: 700_000))
    }

    /// Steam güncellemesi yeni, farklı boyutlu gerçek dosya yazınca eski yedek değişir, dolgu yeni boyuta uyar.
    @Test func steamUpdateReplacesBackupAndResizesPadding() throws {
        let td = try TempDir()
        let bottle = td.url.appendingPathComponent("bottle")
        let proxyFile = try proxy(td)
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", data: Data(repeating: 1, count: 600_000))
        try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: proxyFile)

        let updated = Data(repeating: 2, count: 650_000)
        try td.file("\(Self.cef)/cef.win64/steamwebhelper.exe", data: updated)
        #expect(try SteamWebHelperProxy.apply(bottleURL: bottle, proxyExecutable: proxyFile))
        let dir = td.url.appendingPathComponent("\(Self.cef)/cef.win64")
        #expect(try Data(contentsOf: dir.appendingPathComponent("steamwebhelper_gercek.exe")) == updated)
        #expect(isPaddedProxy(dir.appendingPathComponent("steamwebhelper.exe"), proxy: proxyFixture(), size: 650_000))
    }

    @Test func noSteamNoChange() throws {
        let td = try TempDir()
        #expect(try SteamWebHelperProxy.apply(bottleURL: try td.dir("bottle"), proxyExecutable: try proxy(td)) == false)
    }
}
