import Foundation
import Testing
@testable import KopruCore

struct LaunchTargetTests {
    @Test func windowsPathTarget() {
        #expect(WineArguments.arguments(for: .windowsPath("C:\\Steam\\steam.exe", arguments: ["-a"]))
                == ["C:\\Steam\\steam.exe", "-a"])
    }

    @Test func shortcutUsesStartWait() {
        let lnk = URL(fileURLWithPath: "/B/drive_c/Start Menu/Notepad++.lnk")
        #expect(WineArguments.arguments(for: .shortcut(lnk))
                == ["start", "/wait", "/unix", "/B/drive_c/Start Menu/Notepad++.lnk"])
    }

    @Test func unixFileRunsExeOrMsiexec() {
        #expect(WineArguments.arguments(for: .unixFile(URL(fileURLWithPath: "/D/setup.exe"), arguments: ["/S"]))
                == ["/D/setup.exe", "/S"])
        #expect(WineArguments.arguments(for: .unixFile(URL(fileURLWithPath: "/D/paket.MSI"), arguments: []))
                == ["msiexec", "/i", "/D/paket.MSI"])
    }

    @Test func builtinTarget() {
        #expect(WineArguments.arguments(for: .builtin("wineboot", arguments: ["--init"])) == ["wineboot", "--init"])
    }
}
