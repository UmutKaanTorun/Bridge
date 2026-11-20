import Darwin
import Foundation

/// Bir bottle'ın wineserver'ı çalışıyor mu?
/// wineserver, /tmp/.wine-<uid>/server-<aygıt>-<inode>/lock dosyasında fcntl yazma kilidi tutar;
/// kapanınca kilit kalkar (klasör ve lock dosyası yerinde kalır).
public enum WineServerStatus {
    /// Wine'ın bu bottle için kullandığı sunucu klasörü (bottle klasörünün aygıt ve inode numarası, onaltılı).
    public static func serverDirectory(prefix: URL, tmpRoot: String = "/tmp") -> URL? {
        var info = stat()
        guard stat(prefix.path, &info) == 0 else { return nil }
        let device = String(UInt64(info.st_dev), radix: 16)
        let inode = String(info.st_ino, radix: 16)
        return URL(fileURLWithPath: "\(tmpRoot)/.wine-\(getuid())/server-\(device)-\(inode)", isDirectory: true)
    }

    public static func isRunning(prefix: URL, tmpRoot: String = "/tmp") -> Bool {
        guard let directory = serverDirectory(prefix: prefix, tmpRoot: tmpRoot) else { return false }
        let fd = open(directory.appendingPathComponent("lock").path, O_RDWR)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        lock.l_start = 0
        lock.l_len = 0
        guard fcntl(fd, F_GETLK, &lock) == 0 else { return false }
        return lock.l_type != Int16(F_UNLCK)
    }
}
