import KopruCore
import SwiftUI

/// Kur sayfasında bir oyun platformu. Satır üzerine gelince vurgulanır ama tıklamaya tepki vermez:
/// indirme yüklü bir iş, yanlışlıkla başlamasın diye yalnızca "İndir" düğmesi indirip kurar, "Aç" düğmesi açar.
struct PlatformRow: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe
    @State private var isHovered = false
    @State private var confirmsBroken = false

    private enum Phase {
        case idle
        case busyElsewhere
        case installing(InstallProgress)
        case failed(InstallProgress)
        case installed(Bottle)
    }

    private var phase: Phase {
        if let progress = model.install, progress.source == .recipe(recipe.id) {
            return progress.failedStep != nil ? .failed(progress) : .installing(progress)
        }
        if let bottle = model.installedBottle(for: recipe) { return .installed(bottle) }
        return model.isInstallRunning ? .busyElsewhere : .idle
    }

    var body: some View {
        let phase = phase
        HStack(spacing: 14) {
            RecipeIcon(recipe: recipe, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                status(phase)
            }
            Spacer(minLength: 8)
            trailing(phase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered && highlightsOnHover(phase) ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isBusyElsewhere(phase) ? 0.55 : 1)
        .onHover { isHovered = $0 }
        .help(help(phase))
        .contextMenu { contextMenu(phase) }
        .confirmationDialog("\(recipe.name) şu an Bridge'de çalışmıyor",
                            isPresented: $confirmsBroken) {
            Button("Yine de indir") { model.installRecipe(recipe) }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(recipe.verdict ?? "Kurulum bitse de program açılmayabilir.")
        }
    }

    // MARK: Durum satırı

    @ViewBuilder
    private func status(_ phase: Phase) -> some View {
        switch phase {
        case .idle, .busyElsewhere:
            HStack(spacing: 8) {
                // Not yalnızca uyarı taşıyorsa görünür; "Açılıyor"/"Çalışıyor" platform listesinde gürültü.
                if recipe.rating == .partial || recipe.rating == .broken {
                    RatingBadge(label: recipe.rating.label, tone: recipe.rating.tone)
                }
                if let publisher = recipe.publisher {
                    Text(publisher).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        case let .installing(progress):
            VStack(alignment: .leading, spacing: 4) {
                Text(stepText(progress))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if progress.current == .downloading, let fraction = progress.fraction {
                    ProgressView(value: fraction)
                } else {
                    ProgressView(value: Double(progress.done.count), total: Double(progress.steps.count))
                }
            }
            .controlSize(.small)
            .frame(maxWidth: 220, alignment: .leading)
        case let .failed(progress):
            Text("Kurulamadı: \(progress.errorMessage ?? "bilinmeyen hata")")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        case let .installed(bottle):
            HStack(spacing: 6) {
                Label("Kurulu", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if bottle.info.name != recipe.bottle.defaultName {
                    Text("“\(bottle.info.name)” bottle'ında").font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
        }
    }

    private func stepText(_ progress: InstallProgress) -> String {
        guard let step = progress.current else { return "Hazırlanıyor" }
        if step == .downloading, let fraction = progress.fraction {
            return "\(step.title) \(fraction.formatted(.percent.precision(.fractionLength(0))))"
        }
        return step.title
    }

    // MARK: Sağdaki düğmeler

    @ViewBuilder
    private func trailing(_ phase: Phase) -> some View {
        switch phase {
        case .idle:
            Button { install() } label: {
                Label("İndir", systemImage: "arrow.down.circle")
            }
            .controlSize(.large)
        case .busyElsewhere:
            EmptyView()
        case .installing:
            Button("Durdur") { model.cancelInstall() }
                .help("Kurulumu durdurur; yarım kalan bottle silinir")
        case let .failed(progress):
            HStack(spacing: 6) {
                if let bottle = progress.bottle {
                    Button("Günlük") { model.openLog(model.logURL(for: bottle)) }
                }
                Button("Tekrar dene") { model.retryInstall(recipe) }
                    .buttonStyle(.borderedProminent)
                Button { model.closeInstallPanel() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(progress.bottle == nil ? "Kapat" : "Kapat (yarım bottle kenar çubuğunda kalır)")
            }
        case let .installed(bottle):
            Button("Aç") { model.launchRecipe(in: bottle) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    // MARK: Eylemler

    private func highlightsOnHover(_ phase: Phase) -> Bool {
        switch phase {
        case .idle, .installed: model.isReady
        default: false
        }
    }

    private func isBusyElsewhere(_ phase: Phase) -> Bool {
        if case .busyElsewhere = phase { true } else { false }
    }

    private func install() {
        guard model.isReady else { return }
        if recipe.rating == .broken { confirmsBroken = true } else { model.installRecipe(recipe) }
    }

    private func help(_ phase: Phase) -> String {
        switch phase {
        case .idle:
            ["İndir'e tıkla: Bridge indirip kurar.", recipe.verdict, recipe.downloadNote].compactMap { $0 }.joined(separator: "\n")
        case .busyElsewhere:
            "Önce süren kurulum bitsin."
        case .installing:
            "Kuruluyor; bu sırada başka programlara göz atabilirsin."
        case let .failed(progress):
            progress.errorMessage ?? ""
        case .installed:
            "Aç'a tıkla: \(recipe.launch.name) açılır."
        }
    }

    @ViewBuilder
    private func contextMenu(_ phase: Phase) -> some View {
        switch phase {
        case let .installed(bottle):
            Button("Aç") { model.launchRecipe(in: bottle) }
            Button("Bottle'a git") { model.selection = .bottle(bottle.id) }
        case .installing:
            Button("Durdur") { model.cancelInstall() }
        case let .failed(progress):
            Button("Tekrar dene") { model.retryInstall(recipe) }
            if let bottle = progress.bottle {
                Button("Günlüğü göster") { model.openLog(model.logURL(for: bottle)) }
                if progress.createsBottle {
                    Button("Yarım bottle'ı sil", role: .destructive) { model.deleteFailedInstallBottle() }
                }
            }
            Button("Kapat") { model.closeInstallPanel() }
        case .idle:
            Button("İndir") { install() }
        default:
            EmptyView()
        }
    }
}
