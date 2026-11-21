import KopruCore
import SwiftUI

/// Rozet rengi; anlam taşır (yeşil sorunsuz … kırmızı çalışmıyor).
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
        case .opens: .gray
        case .broken: .red
        }
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

/// Tarifin icon.png'si; yoksa kategori simgesi.
struct RecipeIcon: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let image = model.recipeIcon(for: recipe) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: recipe.category.symbolName)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: size * 0.24))
            }
        }
        .frame(width: size, height: size)
    }
}
