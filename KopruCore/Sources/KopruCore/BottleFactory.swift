import Foundation

public enum InstallStep: String, CaseIterable, Hashable, Sendable {
    case preparing, downloading, installing, configuring

    public var title: String {
        switch self {
        case .preparing: "Bottle hazırlanıyor"
        case .downloading: "İndiriliyor"
        case .installing: "Kuruluyor"
        case .configuring: "Ayarlanıyor"
        }
    }
}

public enum InstallError: Error, Equatable, LocalizedError {
    case prefixInitFailed(exitCode: Int32)
    case installerFailed(exitCode: Int32)

    public var errorDescription: String? {
        switch self {
        case let .prefixInitFailed(code): "Windows ortamı hazırlanamadı (wineboot çıkış kodu \(code))."
        case let .installerFailed(code): "Kurulum programı hata ile bitti (çıkış kodu \(code))."
        }
    }
}

/// Kurulumun hangi adımda ve hangi bottle'da kaldığı.
public struct InstallFailure: Error, LocalizedError {
    public let step: InstallStep
    /// Kurulum sırasında oluşturulan (ya da kullanılan) bottle; ad hatasında nil.
    public let bottle: Bottle?
    public let underlying: any Error

    public init(step: InstallStep, bottle: Bottle?, underlying: any Error) {
        self.step = step
        self.bottle = bottle
        self.underlying = underlying
    }

    public var errorDescription: String? { underlying.localizedDescription }
}

/// Yeni bottle: klasör + kopru.json + wineboot.
public struct BottleFactory: Sendable {
    public let store: BottleStore
    public let runner: WineRunner

    public init(store: BottleStore, runner: WineRunner) {
        self.store = store
        self.runner = runner
    }

    public func create(name: String, settings: BottleSettings, recipeId: String?) async throws -> Bottle {
        let bottle = try store.makeBottle(name: name, settings: settings, recipeId: recipeId)
        // mscoree/mshtml kapalı: wineboot Wine Mono / Gecko indirme penceresi açmasın.
        let result = try await runner.run(.builtin("wineboot", arguments: ["--init"]), in: bottle,
                                          extraEnvironment: ["WINEDLLOVERRIDES": "mscoree=d;mshtml=d"])
        guard result.exitCode == 0 else {
            throw InstallFailure(step: .preparing, bottle: bottle, underlying: InstallError.prefixInitFailed(exitCode: result.exitCode))
        }
        return bottle
    }
}
