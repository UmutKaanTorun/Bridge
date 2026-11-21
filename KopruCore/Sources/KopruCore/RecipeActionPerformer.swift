import Foundation

public enum RecipeActionError: Error, Equatable, LocalizedError {
    case registryFailed(name: String, exitCode: Int32)
    case missingRecipeFile(String)
    case unsafePath(String)
    case invalidJSONFile(String)

    public var errorDescription: String? {
        switch self {
        case let .registryFailed(name, code): "Kayıt defterine “\(name)” yazılamadı (çıkış kodu \(code))."
        case let .missingRecipeFile(path): "Tarif dosyası eksik: \(path)"
        case let .unsafePath(path): "Tarif bottle dışındaki bir yola yazmak istiyor: “\(path)”"
        case let .invalidJSONFile(path): "Ayar dosyası okunamadı (geçerli bir JSON nesnesi değil): \(path)"
        }
    }
}

/// Tarif eylemlerini (afterInstall, beforeLaunch) sırayla uygular.
public struct RecipeActionPerformer: Sendable {
    public let runner: WineRunner
    public let catalog: RecipeCatalog

    public init(runner: WineRunner, catalog: RecipeCatalog) {
        self.runner = runner
        self.catalog = catalog
    }

    public static func registryArguments(key: String, name: String, value: String) -> [String] {
        ["add", key, "/v", name, "/t", "REG_SZ", "/d", value, "/f"]
    }

    public func perform(_ actions: [RecipeAction], recipe: Recipe, bottle: Bottle) async throws {
        for action in actions {
            switch action {
            case let .registry(key, name, value):
                let result = try await runner.run(.builtin("reg", arguments: Self.registryArguments(key: key, name: name, value: value)),
                                                  in: bottle)
                guard result.exitCode == 0 else {
                    throw RecipeActionError.registryFailed(name: name, exitCode: result.exitCode)
                }
            case .steamWebHelperProxy:
                let proxy = catalog.filesDirectory(for: recipe).appendingPathComponent(SteamWebHelperProxy.helperName)
                guard FileManager.default.fileExists(atPath: proxy.path) else {
                    throw RecipeActionError.missingRecipeFile(proxy.path)
                }
                try SteamWebHelperProxy.apply(bottleURL: bottle.url, proxyExecutable: proxy)
            case .stopPrograms:
                await runner.killWineserver(prefix: bottle.url, settings: bottle.info.settings)
            case let .jsonValues(file, values):
                try JSONFileValues.apply(values, toFile: file, inBottleAt: bottle.url)
            case let .helperProxy(file):
                let helper = try JSONFileValues.resolve(file, inBottleAt: bottle.url)
                let proxy = catalog.filesDirectory(for: recipe).appendingPathComponent(helper.lastPathComponent)
                guard FileManager.default.fileExists(atPath: proxy.path) else {
                    throw RecipeActionError.missingRecipeFile(proxy.path)
                }
                try HelperProxy.apply(helper: helper, proxyExecutable: proxy)
            }
        }
    }

    /// `isAlive` doğru olduğu sürece dosya eylemlerini `interval` aralıklarla yeniden uygular.
    /// Wine çalıştıran eylemler (kayıt defteri) atlanır. Önce bekler, sonra denetler: çağrıldığı anda
    /// başlatılan program henüz sayılmamış olabilir.
    public func keepApplying(_ actions: [RecipeAction], recipe: Recipe, bottle: Bottle,
                             every interval: Duration = .seconds(1),
                             while isAlive: @Sendable () -> Bool) async {
        let fileActions = actions.filter(\.isFileAction)
        guard !fileActions.isEmpty else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            guard isAlive() else { return }
            try? await perform(fileActions, recipe: recipe, bottle: bottle)
        }
    }
}
