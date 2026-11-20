import Foundation
import Testing
@testable import KopruCore

struct WindowsPathTests {
    let bottle = URL(fileURLWithPath: "/Bottles/Steam", isDirectory: true)

    @Test func cDriveToUnix() {
        #expect(WindowsPath.toUnix("C:\\Program Files (x86)\\Steam\\steam.exe", bottleURL: bottle)?.path
                == "/Bottles/Steam/drive_c/Program Files (x86)/Steam/steam.exe")
        #expect(WindowsPath.toUnix("c:\\", bottleURL: bottle)?.path == "/Bottles/Steam/drive_c")
    }

    @Test func zDriveToUnix() {
        #expect(WindowsPath.toUnix("Z:\\Users\\umut\\a.exe", bottleURL: bottle)?.path == "/Users/umut/a.exe")
    }

    @Test func unknownPathsAreNil() {
        #expect(WindowsPath.toUnix("D:\\a.exe", bottleURL: bottle) == nil)
        #expect(WindowsPath.toUnix("goreli\\a.exe", bottleURL: bottle) == nil)
    }

    @Test func unixToWindows() {
        #expect(WindowsPath.fromUnix(URL(fileURLWithPath: "/Bottles/Steam/drive_c/Program Files/a.exe"), bottleURL: bottle)
                == "C:\\Program Files\\a.exe")
        #expect(WindowsPath.fromUnix(URL(fileURLWithPath: "/Users/umut/Downloads/setup.exe"), bottleURL: bottle)
                == "Z:\\Users\\umut\\Downloads\\setup.exe")
    }
}
