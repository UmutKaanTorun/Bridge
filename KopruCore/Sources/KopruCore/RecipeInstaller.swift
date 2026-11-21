import Foundation

public enum InstallEvent: Equatable, Sendable {
    case started(InstallStep)
    /// Yalnızca indirme sırasında, 0...1
    case progress(Double)
    case finished(InstallStep)
    case bottleCreated(Bottle)
}

/// Tarifle kurulum: bottle → indir → kur → ayarla.
public struct RecipeInstaller: Sendable {
    public let factory: BottleFactory
    public let runner: WineRunner
    public let actions: RecipeActionPerformer
    public let downloader: Downloader
    public let downloadsDirectory: URL

    public init(factory: BottleFactory, runner: WineRunner, actions: RecipeActionPerformer,
                downloader: Downloader, downloadsDirectory: URL) {
        self.factory = factory
        self.runner = runner
        self.actions = actions
        self.downloader = downloader
        self.downloadsDirectory = downloadsDirectory
    }

    /// Hata her zaman `InstallFailure` olarak gelir. Görev iptal edilirse (kullanıcı durdurdu) altta
    /// `CancellationError` olur; kurulum programı çalışıyorsa bottle'ın wineserver'ı öldürülür.
    public func install(_ recipe: Recipe, bottleName: String,
                        onEvent: @escaping @Sendable (InstallEvent) -> Void) async throws -> Bottle {
        onEvent(.started(.preparing))
        let bottle: Bottle
        do {
            bottle = try await factory.create(name: bottleName, settings: recipe.bottle.settings, recipeId: recipe.id)
        } catch let failure as InstallFailure {
            throw failure
        } catch {
            throw InstallFailure(step: .preparing, bottle: nil, underlying: error)
        }
        onEvent(.bottleCreated(bottle))
        onEvent(.finished(.preparing))

        let installerFile = downloadsDirectory.appendingPathComponent(recipe.installer.fileName)
        try await step(.downloading, bottle, onEvent) {
            try await downloader.download(recipe.installer.url, to: installerFile, sha256: recipe.installer.sha256) {
                onEvent(.progress($0))
            }
        }
        try await step(.installing, bottle, onEvent) {
            // Takılan kurulum programı durdurulabilsin: görev iptal edilince bottle'daki Windows süreçleri kapatılır.
            let result = try await withTaskCancellationHandler {
                try await runner.run(.unixFile(installerFile, arguments: recipe.installer.arguments), in: bottle,
                                     appName: recipe.name)
            } onCancel: {
                Task { await runner.killWineserver(prefix: bottle.url, settings: bottle.info.settings) }
            }
            try Task.checkCancellation()
            guard result.exitCode == 0 else { throw InstallError.installerFailed(exitCode: result.exitCode) }
            guard recipe.isInstalled(in: bottle.url) else { throw InstallError.programMissing(recipe.name) }
        }
        try await step(.configuring, bottle, onEvent) {
            try await actions.perform(recipe.afterInstall, recipe: recipe, bottle: bottle)
        }
        return bottle
    }

    private func step(_ step: InstallStep, _ bottle: Bottle, _ onEvent: @Sendable (InstallEvent) -> Void,
                      _ body: () async throws -> Void) async throws {
        onEvent(.started(step))
        do {
            try Task.checkCancellation()
            try await body()
        } catch {
            throw InstallFailure(step: step, bottle: bottle, underlying: Task.isCancelled ? CancellationError() : error)
        }
        onEvent(.finished(step))
    }
}
