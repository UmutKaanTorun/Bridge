import KopruCore
import SwiftUI

extension EnvironmentValues {
    /// Kur sayfasının arama alanı odakta mı? Odaktayken Return kurulum başlatmasın.
    @Entry var isInstallSearchActive = false
}

/// Kur/Aç düğmelerinin Return kısayolu; arama alanı odaktayken kapalı.
private struct DefaultActionUnlessSearching: ViewModifier {
    @Environment(\.isInstallSearchActive) private var searching

    func body(content: Content) -> some View {
        content.keyboardShortcut(searching ? nil : .defaultAction)
    }
}

extension View {
    func defaultActionUnlessSearching() -> some View {
        modifier(DefaultActionUnlessSearching())
    }
}

/// Paneldeki ana düğme (Kur / Aç): taslaktaki gibi mavi; `wide` ise satırda kalan genişliği doldurur.
struct PrimaryPanelButton: View {
    let title: LocalizedStringKey
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: wide ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .defaultActionUnlessSearching()
    }
}

/// Panel içindeki küçük bölüm başlığı.
struct PanelSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 7)
    }
}

/// Kur sayfasının sağ paneli.
struct InstallInspector: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let progress = model.install, case let .unlisted(file) = progress.source, model.unlistedFile != file {
                HiddenUnlistedInstallRow(file: file, progress: progress)
                Divider()
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let file = model.unlistedFile {
            UnlistedDetail(file: file, defaultBottleID: model.unlistedDefaultBottleID).id(file)
        } else if let entry = model.selectedEntry {
            EntryDetail(entry: entry).id(entry.id)
        } else {
            ContentUnavailableView("Bir program seç", systemImage: "square.grid.2x2",
                                   description: Text("Ayrıntılar ve kurulum burada görünür."))
        }
    }
}

/// Seçili kartın ayrıntısı; altta eylemler.
private struct EntryDetail: View {
    let entry: CatalogEntry

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    verdict.padding(.top, 14)
                    if case let .recipe(recipe) = entry {
                        RecipeFacts(recipe: recipe)
                    }
                }
                .padding(EdgeInsets(top: 26, leading: 22, bottom: 16, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            EntryActions(entry: entry)
                .padding(EdgeInsets(top: 14, leading: 22, bottom: 18, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            EntryIcon(entry: entry, size: 56)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(.title3.bold())
                Text([entry.publisher, entry.summary].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 6) {
            RatingBadge(label: entry.badge.label, tone: entry.badge.tone)
            if let text = entry.verdictText {
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.badge.tone.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Tarifin test bilgisi, Köprü'nün yaptığı ayarlar ve indirme notu.
private struct RecipeFacts: View {
    let recipe: Recipe

    var body: some View {
        if let tested = recipe.testedOn {
            Text("Son test: \(tested.summary)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        if let highlights = recipe.highlights, !highlights.isEmpty {
            PanelSectionTitle("Köprü senin yerine ayarlar")
            ForEach(highlights, id: \.self) { highlight in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(highlight.title)
                        Text(highlight.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        if let note = recipe.downloadNote {
            PanelSectionTitle("İndirilecek")
            Text(note).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Panelin altındaki eylemler.
private struct EntryActions: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry
    @State private var bottleName: String

    init(entry: CatalogEntry) {
        self.entry = entry
        let name = if case let .recipe(recipe) = entry { recipe.bottle.defaultName } else { entry.name }
        _bottleName = State(initialValue: name)
    }

    var body: some View {
        switch entry {
        case let .recipe(recipe):
            recipeActions(recipe)
        case let .upcoming(program):
            TryAnywayActions(broken: program.status == .broken)
        }
    }

    @ViewBuilder
    private func recipeActions(_ recipe: Recipe) -> some View {
        if let progress = model.install, progress.source == .recipe(recipe.id) {
            InstallProgressPanel(progress: progress)
        } else if let bottle = model.installedBottle(for: entry) {
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(bottle.info.name)” bottle'ında kurulu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Bottle'a git") { model.selection = .bottle(bottle.id) }
                        .controlSize(.large)
                    PrimaryPanelButton(title: "Aç", wide: true) { model.launchRecipe(in: bottle) }
                }
            }
        } else if recipe.rating == .broken {
            TryAnywayActions(broken: true)
        } else if model.isInstallRunning {
            RunningInstallNotice()
        } else {
            installForm(recipe)
        }
    }

    private func installForm(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Bottle adı").font(.caption).foregroundStyle(.secondary)
            TextField("Bottle adı", text: $bottleName).labelsHidden()
            if !bottleName.trimmingCharacters(in: .whitespaces).isEmpty && !model.isNameAvailable(bottleName) {
                Text("Bu adla bir bottle var.").font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("İnternet gerekli").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                PrimaryPanelButton(title: "Kur") { model.installRecipe(recipe, bottleName: bottleName) }
                    .disabled(!model.isNameAvailable(bottleName))
            }
            .padding(.top, 7)
        }
    }
}

/// Başka bir kurulum sürerken Kur düğmesinin yerine.
struct RunningInstallNotice: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            Text("Önce süren kurulum bitsin.").foregroundStyle(.secondary)
            Spacer()
            Button("Göster") { model.showRunningInstall() }
        }
    }
}

/// Sağ paneldeki kurulum ilerlemesi: adımlar, hata ve bitiş düğmeleri.
struct InstallProgressPanel: View {
    @Environment(AppModel.self) private var model
    let progress: InstallProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InstallStepsList(progress: progress)
            if let message = progress.errorMessage {
                // Panel altı ScrollView dışında: buradaki metne fixedSize(vertical:) verme. Pencerenin en küçük
                // boyu ölçülürken metin sıfır genişlikte harf harf sarılıp uzar, tüm pencere içeriği yukarı kayar.
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
            if progress.failedStep != nil {
                failedActions
            } else if progress.finished,
                      let bottle = progress.bottle.flatMap({ snapshot in model.bottles.first { $0.id == snapshot.id } }) {
                HStack(spacing: 8) {
                    Button("Bottle'a git") {
                        model.closeInstallPanel()
                        model.selection = .bottle(bottle.id)
                    }
                    .controlSize(.large)
                    if case .recipe = progress.source {
                        PrimaryPanelButton(title: "Aç", wide: true) { model.launchRecipe(in: bottle) }
                    } else {
                        Spacer()
                    }
                }
            } else {
                Text("Bu sırada başka programlara göz atabilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var failedActions: some View {
        if let bottle = progress.bottle {
            Button("Günlüğü göster") { model.openLog(model.logURL(for: bottle)) }
        }
        HStack {
            if progress.createsBottle, progress.bottle != nil {
                Button("Yarım bottle'ı sil", role: .destructive) { model.deleteFailedInstallBottle() }
            }
            Spacer()
            Button(progress.createsBottle && progress.bottle != nil ? "Tut ve kapat" : "Kapat") {
                model.closeInstallPanel()
            }
        }
    }
}

/// Hazır olmayan programda: kurulum dosyasıyla genel ayarlarla deneme.
private struct TryAnywayActions: View {
    @Environment(AppModel.self) private var model
    let broken: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(broken
                 ? "Kurulum dosyasıyla genel ayarlarla yine de deneyebilirsin; sorun çıkarsa günlük dosyası yardımcı olur."
                 : "Kurulum dosyan varsa hazır tarifi beklemeden genel ayarlarla deneyebilirsin.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(broken ? "Yine de dene…" : "Dosya seç…") { model.isPickingInstaller = true }
        }
    }
}

/// Listede olmayan kurulum panelin dışında kaldıysa (kullanıcı bir kart seçti) ona dönüş satırı.
private struct HiddenUnlistedInstallRow: View {
    @Environment(AppModel.self) private var model
    let file: URL
    let progress: InstallProgress

    var body: some View {
        HStack(spacing: 8) {
            if progress.isActive {
                ProgressView().controlSize(.small)
            } else if progress.failedStep != nil {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(file.lastPathComponent).lineLimit(1).truncationMode(.middle)
                Text(progress.isActive ? "Kuruluyor" : progress.failedStep != nil ? "Kurulamadı" : "Kuruldu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Göster") { model.showInstallPage(unlisted: file) }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.4))
    }
}
