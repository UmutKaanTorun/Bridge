import KopruCore
import SwiftUI

/// Rozet rengi; anlam taşır (yeşil sorunsuz … gri test ediliyor).
enum BadgeTone {
    case green, teal, orange, red, gray

    var color: Color {
        switch self {
        case .green: .green
        case .teal: .teal
        case .orange: .orange
        case .red: .red
        case .gray: .secondary
        }
    }
}

extension RecipeRating {
    var tone: BadgeTone {
        switch self {
        case .perfect: .green
        case .works: .teal
        case .partial: .orange
        case .broken: .red
        }
    }
}

extension UpcomingStatus {
    var tone: BadgeTone {
        switch self {
        case .testing: .gray
        case .broken: .red
        }
    }
}

extension CatalogEntry {
    /// Kartta ve panelde gösterilen uyumluluk etiketi.
    var badge: (label: String, tone: BadgeTone) {
        switch self {
        case let .recipe(recipe): (recipe.rating.label, recipe.rating.tone)
        case let .upcoming(program): (program.status.label, program.status.tone)
        }
    }

    /// Paneldeki açıklama cümlesi.
    var verdictText: String? {
        switch self {
        case let .recipe(recipe):
            recipe.verdict
        case let .upcoming(program):
            switch program.status {
            case .testing: "Bu program için kurulum tarifi hazırlanıyor."
            case .broken: program.note ?? "Bu program şu an Köprü'de açılmıyor."
            }
        }
    }

    /// Bu karta ait kurulumun kaynağı; yalnızca tarifler kurulur.
    var installSource: InstallSource? {
        if case let .recipe(recipe) = self { .recipe(recipe.id) } else { nil }
    }
}

/// Renkli nokta + metin kapsülü.
struct RatingBadge: View {
    let label: String
    let tone: BadgeTone

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(tone.color.opacity(0.14), in: Capsule())
    }
}

/// Kart ve panel simgesi: tarifin icon.png'si, yoksa kategori simgesi.
struct EntryIcon: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let image = model.recipeIcon(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: entry.category.symbolName)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: size * 0.24))
            }
        }
        .frame(width: size, height: size)
    }
}
