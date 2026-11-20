import SwiftUI

/// Pencereye kurulum dosyası sürüklenirken detay sütununu kaplayan katman.
struct DropOverlay: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
            Text("Bırak, kuralım").font(.title3.bold())
            Text(".exe ve .msi kurulum dosyaları").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(12)
        }
        .allowsHitTesting(false)
    }
}
