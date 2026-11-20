import AppKit
import KopruCore
import Observation
import os

/// Ekranda gösterilecek hata ya da uyarı.
struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var logURL: URL?
}

/// Açılışta Köprü'yü kullanılamaz yapan sorun.
enum StartupProblem: Equatable {
    case engineMissing(String)
    case rosettaMissing(String)
}

/// "Listede olmayan program"ın kurulacağı yer.
enum UnlistedTarget: Hashable {
    case newBottle(String)
    case existing(Bottle)
}

/// Kenar çubuğunda seçili satır.
enum SidebarItem: Hashable {
    case install
    case bottle(Bottle.ID)
}

/// Kurulumun nereden başladığı; kart ve panel kendi kurulumunu bununla tanır.
enum InstallSource: Hashable {
    /// Tarif id'si
    case recipe(String)
    case unlisted(URL)
    case emptyBottle
}

/// Kurulum ilerleme ekranının durumu.
struct InstallProgress: Identifiable {
    let id = UUID()
    let source: InstallSource
    let title: String
    let steps: [InstallStep]
    /// Yeni bottle açılıyorsa hata ekranı "yarım bottle'ı sil" sunar.
    let createsBottle: Bool
    var current: InstallStep?
    var done: Set<InstallStep> = []
    var fraction: Double?
    var failedStep: InstallStep?
    var errorMessage: String?
    var bottle: Bottle?
    var finished = false

    var isActive: Bool { !finished && failedStep == nil }
}

private let catalogLog = Logger(subsystem: "dev.kopru.Kopru", category: "katalog")

@MainActor
@Observable
final class AppModel {
    let paths: KopruPaths
    let store: BottleStore
    let catalog: RecipeCatalog
    private(set) var runner: WineRunner?
    private(set) var startupProblem: StartupProblem?

    private(set) var bottles: [Bottle] = []
    var selection: SidebarItem?
    /// Kur sayfasında seçili kart.
    var selectedEntryID: CatalogEntry.ID?
    /// Kur sayfası panelinde gösterilen listede olmayan kurulum dosyası; doluyken kart seçimi yerine o görünür.
    var unlistedFile: URL?
    /// Listede olmayan dosya için önerilen bottle (dosya bırakılmadan önce bakılan bottle).
    var unlistedDefaultBottleID: Bottle.ID?
    /// Kur sayfasının kurulum dosyası seçicisi açık mı ("Dosya seç…", "Yine de dene…").
    var isPickingInstaller = false

    /// Seçili bottle; Kur sayfasındayken nil. Eski görünümler için yazılabilir.
    var selectedBottleID: Bottle.ID? {
        get { if case let .bottle(id) = selection { id } else { nil } }
        set { selection = newValue.map(SidebarItem.bottle) }
    }
    private(set) var shortcuts: [ShortcutProgram] = []
    private(set) var runningCounts: [Bottle.ID: Int] = [:]
    /// `whileRunning` koruması çalışan bottle'lar (bottle başına tek görev).
    @ObservationIgnored private var guardedBottles: Set<Bottle.ID> = []
    /// Programların exe'den çıkarılan simgeleri. Bulunamayanlar saklanmaz: program sonradan
    /// kurulunca (ör. Steam ilk açılışta) simgesi bir sonraki gösterimde gelir.
    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    /// Tarif simgeleri (RecipeFiles/<id>/icon.png); bir kez okunur.
    @ObservationIgnored private var recipeIconCache: [String: NSImage] = [:]
    var alert: AppAlert?
    var install: InstallProgress?

    init() {
        let paths = KopruPaths.standard
        self.paths = paths
        store = BottleStore(paths: paths)
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let recipeFiles = resources.appendingPathComponent("RecipeFiles", isDirectory: true)
        do {
            catalog = try RecipeCatalog.load(recipesDirectory: resources.appendingPathComponent("Recipes", isDirectory: true),
                                             filesDirectory: recipeFiles,
                                             upcomingFile: resources.appendingPathComponent("Catalog/upcoming.json"))
        } catch {
            catalogLog.error("Tarif klasörü okunamadı: \(error.localizedDescription, privacy: .public)")
            catalog = RecipeCatalog(recipes: [], filesDirectory: recipeFiles)
        }
        for problem in catalog.problems {
            catalogLog.error("Okunamayan katalog dosyası: \(problem, privacy: .public)")
        }
        do {
            try Engine.checkRosetta()
            let engine = try Engine.locate(bundleResources: Bundle.main.resourceURL,
                                           environment: ProcessInfo.processInfo.environment,
                                           developmentFallback: Self.developmentFallback)
            runner = WineRunner(engine: engine, paths: paths)
        } catch EngineError.rosettaMissing {
            startupProblem = .rosettaMissing(EngineError.rosettaMissing.localizedDescription)
        } catch {
            startupProblem = .engineMissing(error.localizedDescription)
        }
        reload()
    }

    private static var developmentFallback: URL? {
        #if DEBUG
        return Engine.developmentEngine
        #else
        return nil
        #endif
    }

    // MARK: Durum

    var isReady: Bool { runner != nil }

    var isBottlePage: Bool { if case .bottle = selection { true } else { false } }

    var isInstallRunning: Bool { install?.isActive == true }

    var selectedEntry: CatalogEntry? { catalog.entry(id: selectedEntryID) }

    /// Kartın tarifinin kurulu olduğu ilk bottle (detect dosyaları var).
    func installedBottle(for entry: CatalogEntry) -> Bottle? {
        guard case let .recipe(recipe) = entry else { return nil }
        return bottles.withRecipe(recipe.id).first { recipe.isInstalled(in: $0.url) }
    }

    var selectedBottle: Bottle? { bottles.first { $0.id == selectedBottleID } }

    func recipe(for bottle: Bottle) -> Recipe? { catalog.recipe(id: bottle.info.recipeId) }

    var programs: [ProgramItem] {
        guard let bottle = selectedBottle else { return [] }
        return ProgramList.items(recipeLaunch: recipe(for: bottle)?.launch,
                                 pinned: bottle.info.pinnedPrograms,
                                 shortcuts: shortcuts,
                                 bottleURL: bottle.url)
    }

    func isRunning(_ bottle: Bottle) -> Bool { (runningCounts[bottle.id] ?? 0) > 0 }

    func isNameAvailable(_ name: String) -> Bool { (try? store.validateNewName(name)) != nil }

    func reload(select id: Bottle.ID? = nil) {
        do {
            bottles = try store.list()
        } catch {
            show("Bottle'lar okunamadı", error)
        }
        if let id { selection = .bottle(id) }
        // Seçim yoksa ya da seçili bottle silindiyse: ilk bottle, o da yoksa Kur sayfası.
        if selection == nil || (isBottlePage && selectedBottle == nil) {
            selection = bottles.first.map { .bottle($0.id) } ?? .install
        }
        rescan()
    }

    func rescan() {
        guard let bottle = selectedBottle else {
            shortcuts = []
            return
        }
        let hidden = Set(bottle.info.hiddenShortcuts).union(recipe(for: bottle)?.hideShortcuts ?? [])
        shortcuts = ProgramScanner.scan(bottleURL: bottle.url, hidden: hidden)
    }

    /// Kutucuğun gerçek program simgesi; dosya okuması ana iş parçacığının dışında yapılır.
    func icon(for item: ProgramItem, in bottle: Bottle) async -> NSImage? {
        let key = "\(bottle.folderName)|\(item.id)"
        if let cached = iconCache[key] { return cached }
        let bottleURL = bottle.url
        let data = await Task.detached(priority: .utility) {
            ProgramIcon.icoData(for: item, bottleURL: bottleURL)
        }.value
        guard let data, let image = NSImage(data: data) else { return nil }
        iconCache[key] = image
        return image
    }

    /// Kartın tarif simgesi; "Yakında" girdilerinde ve simgesi olmayan tarifte nil.
    func recipeIcon(for entry: CatalogEntry) -> NSImage? {
        guard case let .recipe(recipe) = entry else { return nil }
        if let cached = recipeIconCache[recipe.id] { return cached }
        guard let url = catalog.iconURL(for: recipe.id), let image = NSImage(contentsOf: url) else { return nil }
        recipeIconCache[recipe.id] = image
        return image
    }

    // MARK: Programları açma

    func launch(_ item: ProgramItem) {
        guard let runner, let bottle = selectedBottle else { return }
        start(item.target, name: item.name, in: bottle, runner: runner)
    }

    /// Tarifin başlatıcısını verilen bottle'da açar (Kur sayfasındaki "Aç"); sayfa değişmez.
    func launchRecipe(in bottle: Bottle) {
        guard let runner, let launch = recipe(for: bottle)?.launch else { return }
        let target = LaunchTarget.windowsPath(launch.windowsPath, arguments: launch.arguments(forBottleAt: bottle.url))
        start(target, name: launch.name, in: bottle, runner: runner)
    }

    func runExecutable(_ file: URL, pin: Bool) {
        guard let runner, var bottle = selectedBottle else { return }
        if pin {
            let program = PinnedProgram(name: file.deletingPathExtension().lastPathComponent,
                                        windowsPath: WindowsPath.fromUnix(file, bottleURL: bottle.url))
            if !bottle.info.pinnedPrograms.contains(program) {
                bottle.info.pinnedPrograms.append(program)
                save(bottle)
            }
        }
        start(.unixFile(file, arguments: []), name: file.deletingPathExtension().lastPathComponent, in: bottle, runner: runner)
    }

    private func start(_ target: LaunchTarget, name: String, in bottle: Bottle, runner: WineRunner) {
        let recipe = recipe(for: bottle)
        let desktopSize = bottle.info.settings.virtualDesktop.size(visibleScreen: Self.visibleScreen())
        let actions = RecipeActionPerformer(runner: runner, catalog: catalog)
        runningCounts[bottle.id, default: 0] += 1
        Task {
            defer {
                runningCounts[bottle.id, default: 1] -= 1
                rescan()
            }
            do {
                if let recipe {
                    try await actions.perform(recipe.beforeLaunch, recipe: recipe, bottle: bottle)
                    startGuard(recipe: recipe, bottle: bottle, runner: runner, actions: actions)
                }
                let result = try await runner.run(target, in: bottle, desktopSize: desktopSize, appName: name)
                if result.exitCode != 0 && result.duration < 5 {
                    alert = AppAlert(title: "\(name) hemen kapandı",
                                     message: "Program açıldıktan hemen sonra kapandı (çıkış kodu \(result.exitCode)). Ayrıntılar günlük dosyasında.",
                                     logURL: logURL(for: bottle))
                }
            } catch {
                show("\(name) açılamadı", error, log: bottle)
            }
        }
    }

    /// Tarifin `whileRunning` eylemlerini, bottle'da Wine çalıştığı sürece yeniden uygular.
    /// Köprü'nün başlattığı süreç bitse bile (ör. Steam kendini yeniden başlatınca) wineserver açık
    /// olduğu sürece devam eder.
    private func startGuard(recipe: Recipe, bottle: Bottle, runner: WineRunner, actions: RecipeActionPerformer) {
        guard let whileRunning = recipe.whileRunning, !whileRunning.isEmpty, !guardedBottles.contains(bottle.id) else { return }
        guardedBottles.insert(bottle.id)
        let prefix = bottle.url
        Task {
            await actions.keepApplying(whileRunning, recipe: recipe, bottle: bottle, while: {
                runner.isRunning(bottle) || WineServerStatus.isRunning(prefix: prefix)
            })
            guardedBottles.remove(bottle.id)
        }
    }

    private static func visibleScreen() -> PixelSize {
        let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1640, height: 1040)
        return PixelSize(width: Int(frame.width), height: Int(frame.height))
    }

    func removeFromList(_ item: ProgramItem) {
        guard var bottle = selectedBottle else { return }
        switch item.source {
        case let .shortcut(shortcut):
            bottle.info.hiddenShortcuts.append(shortcut.relativePath)
        case let .pinned(program):
            bottle.info.pinnedPrograms.removeAll { $0 == program }
        case .recipe:
            return
        }
        save(bottle)
        rescan()
    }

    func reveal(_ item: ProgramItem) {
        guard let bottle = selectedBottle else { return }
        let url: URL? = switch item.source {
        case let .shortcut(shortcut): shortcut.url
        case let .pinned(program): WindowsPath.toUnix(program.windowsPath, bottleURL: bottle.url)
        case let .recipe(launch): WindowsPath.toUnix(launch.windowsPath, bottleURL: bottle.url)
        }
        if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    private func shutdownTarget(for bottle: Bottle) -> LaunchTarget? {
        guard let launch = recipe(for: bottle)?.launch, let arguments = launch.shutdownArguments else { return nil }
        return .windowsPath(launch.windowsPath, arguments: arguments)
    }

    func stopSelected() {
        guard let runner, let bottle = selectedBottle else { return }
        let shutdown = shutdownTarget(for: bottle)
        Task { await runner.stop(bottle, shutdown: shutdown) }
    }

    // MARK: Kurulum

    /// Kur sayfasına geçer; `file` verilirse panel o kurulum dosyasını gösterir.
    func showInstallPage(unlisted file: URL? = nil) {
        if let file {
            unlistedDefaultBottleID = selectedBottleID
            unlistedFile = file
        }
        selection = .install
    }

    func selectEntry(_ id: CatalogEntry.ID) {
        selectedEntryID = id
        unlistedFile = nil
    }

    /// Süren kurulumun paneline döner.
    func showRunningInstall() {
        switch install?.source {
        case let .recipe(id):
            selectedEntryID = catalog.recipe(id: id).map { CatalogEntry.recipe($0).id }
            unlistedFile = nil
            selection = .install
        case let .unlisted(file):
            showInstallPage(unlisted: file)
        case .emptyBottle, nil:
            break
        }
    }

    /// Paneldeki biten ya da başarısız kurulumu kapatır; listede olmayan dosyanın panelini de temizler.
    func closeInstallPanel() {
        if case .unlisted = install?.source { unlistedFile = nil }
        install = nil
    }

    func installRecipe(_ recipe: Recipe, bottleName: String) {
        guard let runner else { return }
        install = InstallProgress(source: .recipe(recipe.id), title: "\(recipe.name) kuruluyor",
                                  steps: InstallStep.allCases, createsBottle: true)
        let installer = RecipeInstaller(factory: BottleFactory(store: store, runner: runner),
                                        runner: runner,
                                        actions: RecipeActionPerformer(runner: runner, catalog: catalog),
                                        downloader: Downloader(),
                                        downloadsDirectory: paths.downloads)
        Task {
            do {
                let bottle = try await installer.install(recipe, bottleName: bottleName) { event in
                    Task { @MainActor in self.apply(event) }
                }
                finishInstall(bottle)
            } catch {
                failInstall(error)
            }
        }
    }

    func installUnlisted(file: URL, target: UnlistedTarget) {
        guard let runner else { return }
        let createsBottle: Bool = if case .newBottle = target { true } else { false }
        install = InstallProgress(source: .unlisted(file),
                                  title: "\(file.lastPathComponent) kuruluyor",
                                  steps: createsBottle ? [.preparing, .installing] : [.installing],
                                  createsBottle: createsBottle)
        let factory = BottleFactory(store: store, runner: runner)
        Task {
            var bottle: Bottle?
            do {
                switch target {
                case let .existing(existing):
                    bottle = existing
                case let .newBottle(name):
                    apply(.started(.preparing))
                    let created = try await factory.create(name: name, settings: .default, recipeId: nil)
                    bottle = created
                    apply(.bottleCreated(created))
                    apply(.finished(.preparing))
                }
                guard let bottle else { return }
                apply(.started(.installing))
                let result = try await runner.run(.unixFile(file, arguments: []), in: bottle,
                                                  appName: file.deletingPathExtension().lastPathComponent)
                guard result.exitCode == 0 else {
                    throw InstallFailure(step: .installing, bottle: bottle,
                                         underlying: InstallError.installerFailed(exitCode: result.exitCode))
                }
                finishInstall(bottle)
            } catch let failure as InstallFailure {
                failInstall(failure)
            } catch {
                failInstall(InstallFailure(step: install?.current ?? .preparing, bottle: bottle, underlying: error))
            }
        }
    }

    func createEmptyBottle(name: String) {
        guard let runner else { return }
        install = InstallProgress(source: .emptyBottle, title: "\(name) oluşturuluyor", steps: [.preparing], createsBottle: true)
        Task {
            do {
                apply(.started(.preparing))
                let bottle = try await BottleFactory(store: store, runner: runner).create(name: name, settings: .default, recipeId: nil)
                finishInstall(bottle)
            } catch {
                failInstall(error)
            }
        }
    }

    private func apply(_ event: InstallEvent) {
        guard var progress = install, progress.isActive else { return }
        switch event {
        case let .started(step):
            progress.current = step
            progress.fraction = nil
        case let .progress(fraction):
            progress.fraction = fraction
        case let .finished(step):
            progress.done.insert(step)
            if progress.current == step { progress.current = nil }
        case let .bottleCreated(bottle):
            progress.bottle = bottle
        }
        install = progress
        if case .bottleCreated = event { reload() }
    }

    private func finishInstall(_ bottle: Bottle) {
        if var progress = install {
            progress.done = Set(progress.steps)
            progress.current = nil
            progress.finished = true
            progress.bottle = bottle
            install = progress
        }
        // Kur sayfasından başlayan kurulumda sayfa değişmez; kenar çubuğundan açılan boş bottle seçilir.
        if install?.source == .emptyBottle { reload(select: bottle.id) } else { reload() }
    }

    private func failInstall(_ error: any Error) {
        guard var progress = install else { return }
        let failure = error as? InstallFailure
        progress.failedStep = failure?.step ?? progress.current ?? progress.steps.first
        progress.errorMessage = error.localizedDescription
        if progress.bottle == nil, progress.createsBottle { progress.bottle = failure?.bottle }
        progress.current = nil
        install = progress
        reload()
    }

    func deleteFailedInstallBottle() {
        if let progress = install, progress.createsBottle, let bottle = progress.bottle {
            deleteBottle(bottle)
        }
        closeInstallPanel()
    }

    // MARK: Bottle yönetimi

    func importBottle(from folder: URL, name: String) {
        guard let runner else { return }
        Task {
            // Taşımadan önce o bottle'da çalışan Windows süreçleri kapatılır.
            await runner.killWineserver(prefix: folder, settings: .default)
            do {
                let bottle = try store.importBottle(from: folder, name: name, catalog: catalog)
                reload(select: bottle.id)
            } catch {
                show("Bottle içe aktarılamadı", error)
            }
        }
    }

    func update(_ bottle: Bottle, name: String, settings: BottleSettings) {
        guard let runner else { return }
        let shutdown = shutdownTarget(for: bottle)
        Task {
            do {
                var updated = bottle
                if updated.info.name != name.trimmingCharacters(in: .whitespacesAndNewlines) {
                    updated = try store.rename(updated, to: name)
                }
                // Bir bottle'daki bütün süreçler aynı MSync ayarıyla başlamalı; değişince bottle durdurulur.
                if updated.info.settings.msync != settings.msync {
                    await runner.stop(updated, shutdown: shutdown)
                }
                updated.info.settings = settings
                try store.save(updated)
                reload(select: updated.id)
            } catch {
                show("Ayarlar kaydedilemedi", error)
            }
        }
    }

    func deleteBottle(_ bottle: Bottle) {
        let shutdown = shutdownTarget(for: bottle)
        Task {
            if let runner { await runner.stop(bottle, shutdown: shutdown) }
            do {
                try store.delete(bottle)
                if selectedBottleID == bottle.id { selectedBottleID = nil }
                reload()
            } catch {
                show("Bottle silinemedi", error)
            }
        }
    }

    private func save(_ bottle: Bottle) {
        do {
            try store.save(bottle)
            if let index = bottles.firstIndex(where: { $0.id == bottle.id }) { bottles[index] = bottle }
        } catch {
            show("Bottle kaydedilemedi", error)
        }
    }

    // MARK: Yardımcılar

    func openDriveC() {
        if let bottle = selectedBottle { NSWorkspace.shared.open(bottle.driveC) }
    }

    func openWineSettings(_ bottle: Bottle) {
        guard let runner else { return }
        start(.builtin("winecfg", arguments: []), name: "Windows Ayarları", in: bottle, runner: runner)
    }

    func logURL(for bottle: Bottle) -> URL { paths.logFile(forBottleFolder: bottle.folderName) }

    func openLog(_ url: URL) { NSWorkspace.shared.open(url) }

    private func show(_ title: String, _ error: any Error, log bottle: Bottle? = nil) {
        alert = AppAlert(title: title, message: error.localizedDescription, logURL: bottle.map(logURL(for:)))
    }
}
