import Foundation
import Testing
@testable import KopruCore

struct LaunchTargetTests {
    @Test func windowsPathTarget() {
        #expect(WineArguments.arguments(for: .windowsPath("C:\\Steam\\steam.exe", arguments: ["-a"]), desktop: nil)
                == ["C:\\Steam\\steam.exe", "-a"])
    }

    @Test func shortcutUsesStartWait() {
        let lnk = URL(fileURLWithPath: "/B/drive_c/Start Menu/Notepad++.lnk")
        #expect(WineArguments.arguments(for: .shortcut(lnk), desktop: nil)
                == ["start", "/wait", "/unix", "/B/drive_c/Start Menu/Notepad++.lnk"])
    }

    @Test func unixFileRunsExeOrMsiexec() {
        #expect(WineArguments.arguments(for: .unixFile(URL(fileURLWithPath: "/D/setup.exe"), arguments: ["/S"]), desktop: nil)
                == ["/D/setup.exe", "/S"])
        #expect(WineArguments.arguments(for: .unixFile(URL(fileURLWithPath: "/D/paket.MSI"), arguments: []), desktop: nil)
                == ["msiexec", "/i", "/D/paket.MSI"])
    }

    @Test func builtinTarget() {
        #expect(WineArguments.arguments(for: .builtin("wineboot", arguments: ["--init"]), desktop: nil) == ["wineboot", "--init"])
    }

    @Test func desktopWrapsWithExplorer() {
        let desktop = DesktopWindow(name: "Kopru-Steam", size: PixelSize(width: 1472, height: 904))
        #expect(WineArguments.arguments(for: .windowsPath("C:\\a.exe", arguments: []), desktop: desktop)
                == ["explorer", "/desktop=Kopru-Steam,1472x904", "C:\\a.exe"])
    }
}
