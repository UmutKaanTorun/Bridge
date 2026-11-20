import Foundation
import Testing
@testable import KopruCore

struct KopruPathsTests {
    @Test func derivesSubfolders() {
        let paths = KopruPaths(applicationSupport: URL(fileURLWithPath: "/tmp/AS/Kopru"),
                               logs: URL(fileURLWithPath: "/tmp/Logs/Kopru"))
        #expect(paths.bottles.path == "/tmp/AS/Kopru/Bottles")
        #expect(paths.downloads.path == "/tmp/AS/Kopru/Downloads")
        #expect(paths.logFile(forBottleFolder: "Steam").path == "/tmp/Logs/Kopru/Steam.log")
    }

    @Test func standardUsesUserLibrary() {
        let paths = KopruPaths.standard
        #expect(paths.applicationSupport.path.hasSuffix("Library/Application Support/Kopru"))
        #expect(paths.logs.path.hasSuffix("Library/Logs/Kopru"))
    }
}
