import Foundation
import Testing
@testable import KopruCore

struct WineServerStatusTests {
    @Test func serverDirectoryUsesDeviceAndInodeInHex() throws {
        let td = try TempDir()
        let prefix = try td.dir("bottle")
        var info = stat()
        #expect(stat(prefix.path, &info) == 0)
        let expected = "/tmp/.wine-\(getuid())/server-\(String(UInt64(info.st_dev), radix: 16))-\(String(info.st_ino, radix: 16))"
        #expect(WineServerStatus.serverDirectory(prefix: prefix, tmpRoot: "/tmp")?.path == expected)
    }

    @Test func missingServerIsNotRunning() throws {
        let td = try TempDir()
        #expect(!WineServerStatus.isRunning(prefix: try td.dir("bottle"), tmpRoot: td.url.path))
    }

    @Test func unlockedLockFileIsNotRunning() throws {
        let td = try TempDir()
        let prefix = try td.dir("bottle")
        let lock = try #require(WineServerStatus.serverDirectory(prefix: prefix, tmpRoot: td.url.path)).appendingPathComponent("lock")
        try td.file(String(lock.path.dropFirst(td.url.path.count + 1)))
        #expect(!WineServerStatus.isRunning(prefix: prefix, tmpRoot: td.url.path))
    }

    /// wineserver çalışırken lock dosyasında fcntl yazma kilidi tutar; başka bir süreçle taklit edilir.
    @Test func lockHeldByAnotherProcessMeansRunning() async throws {
        let td = try TempDir()
        let prefix = try td.dir("bottle")
        let lock = try #require(WineServerStatus.serverDirectory(prefix: prefix, tmpRoot: td.url.path)).appendingPathComponent("lock")
        try td.file(String(lock.path.dropFirst(td.url.path.count + 1)))

        let holder = Process()
        holder.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        holder.arguments = ["-c", "import fcntl,sys,time; f=open(sys.argv[1],'r+'); fcntl.lockf(f, fcntl.LOCK_EX); print('kilitli', flush=True); time.sleep(10)", lock.path]
        let output = Pipe()
        holder.standardOutput = output
        try holder.run()
        defer { holder.terminate() }
        _ = output.fileHandleForReading.availableData   // "kilitli" satırını bekle

        #expect(WineServerStatus.isRunning(prefix: prefix, tmpRoot: td.url.path))
        holder.terminate()
        holder.waitUntilExit()
        #expect(!WineServerStatus.isRunning(prefix: prefix, tmpRoot: td.url.path))
    }
}
