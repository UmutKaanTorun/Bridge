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
    /// Kurulum programı hatasız bitti ama tarifin `detect` dosyaları yok.
    case programMissing(String)

    public var errorDescription: String? {
        switch self {
        case let .prefixInitFailed(code): "Windows ortamı hazırlanamadı (wineboot çıkış kodu \(code))."
        case let .installerFailed(code): "Kurulum programı hata ile bitti (çıkış kodu \(code))."
        case let .programMissing(name): "Kurulum bitti ama \(name) bottle'da bulunamadı."
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
        // Durdurulursa wineboot'un bitmesi beklenmez: wineboot sonlandırılır (WineRunner), başlattığı
        // Windows süreçleri de wineserver -k ile kapanır; yarım bottle'ı silmek çağırana kalır.
        try await withTaskCancellationHandler {
            // mscoree/mshtml kapalı: wineboot Wine Mono / Gecko indirme penceresi açmasın.
            let result = try await runner.run(.builtin("wineboot", arguments: ["--init"]), in: bottle,
                                              extraEnvironment: ["WINEDLLOVERRIDES": "mscoree=d;mshtml=d"])
            try Self.throwIfCancelled(bottle)
            guard result.exitCode == 0 else {
                throw InstallFailure(step: .preparing, bottle: bottle, underlying: InstallError.prefixInitFailed(exitCode: result.exitCode))
            }
            // wineboot bitince kayıt defteri henüz diskte değil; wineserver kapanıp yazana kadar bekle (~7 sn).
            await runner.waitForWineserver(prefix: bottle.url, settings: bottle.info.settings)
            try Self.throwIfCancelled(bottle)
        } onCancel: {
            Task { await runner.killWineserver(prefix: bottle.url, settings: bottle.info.settings) }
        }
        return bottle
    }

    private static func throwIfCancelled(_ bottle: Bottle) throws {
        if Task.isCancelled { throw InstallFailure(step: .preparing, bottle: bottle, underlying: CancellationError()) }
    }
}
