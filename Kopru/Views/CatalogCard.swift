import KopruCore
import SwiftUI

/// Kur sayfasındaki program kartı.
struct CatalogCard: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            EntryIcon(entry: entry)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                status.padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(.background),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator),
                              lineWidth: isSelected ? 1.5 : 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var status: some View {
        if let progress = model.install, progress.source == entry.installSource, !progress.finished {
            if progress.failedStep != nil {
                RatingBadge(label: "Kurulamadı", tone: .red)
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    if progress.current == .downloading, let fraction = progress.fraction {
                        Text("Kuruluyor \(fraction, format: .percent.precision(.fractionLength(0)))")
                    } else {
                        Text("Kuruluyor")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else if let bottle = model.installedBottle(for: entry) {
            HStack {
                Label("Kurulu", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Aç") { model.launchRecipe(in: bottle) }
                    .controlSize(.small)
            }
        } else {
            RatingBadge(label: entry.badge.label, tone: entry.badge.tone)
        }
    }
}
