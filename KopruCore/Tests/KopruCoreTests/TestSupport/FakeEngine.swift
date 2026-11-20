import Foundation
@testable import KopruCore

extension TempDir {
    /// bin/wine ve bin/wineserver yerine çağrıları kayit.txt'ye yazan sahte betikler.
    /// Ortam değişkenleri: KAYIT (kayıt dosyası), CIKIS (çıkış kodu), UYKU (saniye),
    /// HATALI (argümanlarda bu metin geçerse 7 ile çıkar).
    func fakeEngine() throws -> Engine {
        let script = """
        #!/bin/sh
        printf '%s %s\\n' "$(basename "$0")" "$*" >> "$KAYIT"
        printf 'WINEPREFIX=%s WINEMSYNC=%s PWD=%s\\n' "$WINEPREFIX" "$WINEMSYNC" "$(pwd)" >> "$KAYIT"
        echo "sahte cikti"
        if [ -n "$HATALI" ]; then case "$*" in *"$HATALI"*) exit 7 ;; esac; fi
        if [ -n "$UYKU" ]; then sleep "$UYKU"; fi
        exit "${CIKIS:-0}"
        """
        for name in ["wine", "wineserver"] {
            let file = try self.file("engine/bin/\(name)", script)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        try dir("engine/lib")
        return Engine(root: url.appendingPathComponent("engine", isDirectory: true))
    }

    var recordFile: URL { url.appendingPathComponent("kayit.txt") }

    func recordedLines() -> [String] {
        ((try? String(contentsOf: recordFile, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    /// Gerçek ortam (PATH için) + KAYIT + verilenler.
    func environment(_ extra: [String: String] = [:]) -> [String: String] {
        ProcessInfo.processInfo.environment
            .merging(["KAYIT": recordFile.path]) { _, new in new }
            .merging(extra) { _, new in new }
    }
}
