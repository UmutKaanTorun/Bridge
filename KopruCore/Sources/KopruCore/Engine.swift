import Foundation

public enum EngineError: Error, Equatable, LocalizedError {
    case notFound(searched: [String])
    case rosettaMissing

    public var errorDescription: String? {
        switch self {
        case let .notFound(searched):
            "Wine motoru bulunamadı. Aranan yerler:\n" + searched.joined(separator: "\n")
        case .rosettaMissing:
            "Bridge'in çalışması için Rosetta gerekiyor. Terminal'de şu komutu çalıştır:\nsoftwareupdate --install-rosetta --agree-to-license"
        }
    }
}

/// CrossOver 26.3.0 kaynağından derlenmiş Wine 11.0 + DXMT motoru. `oyun26.sh`'in karşılığı.
public struct Engine: Sendable, Equatable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public var wine: URL { root.appendingPathComponent("bin/wine") }
    public var wineserver: URL { root.appendingPathComponent("bin/wineserver") }
    public var libraries: URL { root.appendingPathComponent("lib", isDirectory: true) }

    /// Geliştirme sırasında kullanılan motor (Faz 0'da derlendi).
    public static let developmentEngine = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("WineEngines/WineCX26.3.0-DXMT0.80", isDirectory: true)

    public static let rosettaRuntimePath = "/Library/Apple/usr/libexec/oah/libRosettaRuntime"

    /// Dock, Wine süreçlerini çalışan dosyanın adıyla ("wine") gösterir; sonradan ad değiştirmeyi
    /// (LSDisplayName, CPSSetProcessName) dikkate almaz. Motor (ntdll, Köprü yaması) bu değişken
    /// varken her Windows sürecini yükleyicinin bu adı taşıyan bir bağlantısından başlatır
    /// ($TMPDIR/winetemp-…/<ad>, CrossOver Hack 22144). Yama: Tools/motor-yamalari/ntdll-dock-adi.patch
    public static let appNameVariable = "KOPRU_APP_NAME"

    /// Virgülle ayrılmış exe adları. Motor (ntdll, Köprü yaması) ana programı bunlardan biri olan süreçte
    /// `orijinal-grafik/` klasörünü (Wine'ın d3d11, dxgi, d3d10core'u) DLL yolunun başına koyar; o program
    /// DXMT yerine wined3d ile çizer. Yama: Tools/motor-yamalari/ntdll-program-basina-wined3d.patch
    public static let wined3dProgramsVariable = "KOPRU_WINED3D_EXE"

    /// DXMT bu değişken "1" iken swapchain'i MetalFX uzamsal ölçekleyiciyle kurar (ölçek varsayılanı 2×,
    /// `d3d11.metalSpatialUpscaleFactor`). Aygıt desteklemiyorsa DXMT normal swapchain'e döner.
    public static let metalFXVariable = "DXMT_METALFX_SPATIAL_SWAPCHAIN"

    /// Rosetta bu değişken "1" iken AVX ve AVX2'yi CPUID'de bildirir (varsayılan: bildirmez).
    public static let advertiseAVXVariable = "ROSETTA_ADVERTISE_AVX"

    public static func isValid(_ root: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: root.appendingPathComponent("bin/wine").path)
    }

    /// Arama sırası: uygulamanın içi (Resources/Motor) → KOPRU_MOTOR → geliştirme motoru.
    public static func locate(bundleResources: URL?, environment: [String: String], developmentFallback: URL?) throws -> Engine {
        var candidates: [URL] = []
        if let bundleResources {
            candidates.append(bundleResources.appendingPathComponent("Motor", isDirectory: true))
        }
        if let custom = environment["KOPRU_MOTOR"], !custom.isEmpty {
            candidates.append(URL(fileURLWithPath: custom, isDirectory: true))
        }
        if let developmentFallback {
            candidates.append(developmentFallback)
        }
        guard let found = candidates.first(where: isValid) else {
            throw EngineError.notFound(searched: candidates.map(\.path))
        }
        return Engine(root: found)
    }

    /// Motor x86_64; Apple Silicon'da Rosetta olmadan açılmaz.
    public static func checkRosetta(fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) throws {
        guard fileExists(rosettaRuntimePath) else { throw EngineError.rosettaMissing }
    }

    /// Wine'a verilecek ortam değişkenleri: `base`'in üzerine Köprü'nün değerleri yazılır.
    public func environment(prefix: URL, settings: BottleSettings,
                            base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var env = base
        env["WINEPREFIX"] = prefix.path
        env["DYLD_FALLBACK_LIBRARY_PATH"] = libraries.path
        env["WINEMSYNC"] = settings.msync ? "1" : "0"
        env["MVK_CONFIG_LOG_LEVEL"] = "0"
        env["WINEDEBUG"] = base["WINEDEBUG"] ?? "-all"
        env["MTL_HUD_ENABLED"] = settings.fpsHud ? "1" : nil
        let wined3d = (settings.wined3dPrograms ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(",") }
        env[Self.wined3dProgramsVariable] = wined3d.isEmpty ? nil : wined3d.joined(separator: ",")
        env[Self.metalFXVariable] = settings.metalFXUpscale == true ? "1" : nil
        env[Self.advertiseAVXVariable] = settings.advertiseAVX == true ? "1" : nil
        return env
    }
}
