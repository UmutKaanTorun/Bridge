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

/// Penceredeki ana düğme (Kur / Aç): mavi; `wide` ise satırda kalan genişliği doldurur.
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

/// Kurulum dosyası penceresindeki ilerleme: adımlar, hata ve bitiş düğmeleri.
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
                HStack {
                    Text("Bu sırada başka programlara göz atabilirsin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if case .unlisted = progress.source {
                        Button("Gizle") { model.unlistedFile = nil }
                    }
                }
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
