import KopruCore
import SwiftUI

/// Seçili bottle'ın sayfası. Tarifli bottle'da üstte platformun başlığı (tek tıkla Aç / Durdur), altında
/// öteki programlar ve oyunlar; tarifsiz bottle'da (boş bottle, listede olmayan program) yalnızca ızgara.
struct BottlePage: View {
    @Environment(AppModel.self) private var model
    let bottle: Bottle

    var body: some View {
        let items = model.programs
        let launcher = items.first { if case .recipe = $0.source { true } else { false } }
        Group {
            if let recipe = model.recipe(for: bottle), let launcher {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PlatformHeader(recipe: recipe, launcher: launcher, bottle: bottle)
                            .padding(20)
                        Divider().padding(.horizontal, 20)
                        OtherPrograms(items: items.filter { $0.id != launcher.id }, bottle: bottle)
                    }
                }
                .modifier(HidesToolbarTitle())
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label("Bu bottle'da program yok", systemImage: "square.dashed")
                } description: {
                    Text("Kur'a bas ya da bir kurulum dosyasını (.exe, .msi) bu pencereye sürükle.")
                }
            } else {
                ScrollView {
                    ProgramTiles(items: items, bottle: bottle).padding(20)
                }
                .navigationSubtitle(model.isRunning(bottle) ? "Çalışıyor" : "")
            }
        }
        .navigationTitle(bottle.info.name)
    }
}

/// Ad başlıkta yazıyor; pencere başlığı (Pencere menüsü için) kalır, araç çubuğunda tekrarlanmaz.
/// macOS 14'te başlık görünür kalır.
private struct HidesToolbarTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}

/// Platformun kendisi: simge, ad, durum ve tek tıkla Aç (çalışırken Durdur).
private struct PlatformHeader: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe
    let launcher: ProgramItem
    let bottle: Bottle

    var body: some View {
        let isRunning = model.isRunning(bottle)
        HStack(spacing: 16) {
            RecipeIcon(recipe: recipe, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if isRunning {
                        Circle().fill(.green).frame(width: 7, height: 7)
                    }
                    Text(status(isRunning: isRunning))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            if isRunning {
                Button { model.stopSelected() } label: {
                    Label("Durdur", systemImage: "stop.fill")
                }
                .controlSize(.large)
                .disabled(!model.isReady)
                .help("Bu bottle'daki bütün Windows programlarını kapatır")
            } else {
                Button { model.launch(launcher) } label: {
                    Label("Aç", systemImage: "play.fill")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.isReady)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Finder'da Göster") { model.reveal(launcher) }
        }
    }

    /// "Epic Games · Kapalı"; bottle'ın adı tariften farklıysa o da yazılır ("Steam 2" bottle'ı).
    private func status(isRunning: Bool) -> String {
        var parts: [String] = []
        if let publisher = recipe.publisher { parts.append(publisher) }
        if bottle.info.name != recipe.name { parts.append("“\(bottle.info.name)” bottle'ı") }
        parts.append(isRunning ? "Çalışıyor" : "Kapalı")
        return parts.joined(separator: " · ")
    }
}

/// Platformun başlığı altındaki bölüm: oyunlar, sabitlenen programlar, Başlat menüsü kısayolları.
private struct OtherPrograms: View {
    let items: [ProgramItem]
    let bottle: Bottle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Oyunlar ve programlar")
                .font(.headline)
            if items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kurduğun oyunlar burada görünür.")
                    Text("Başka bir Windows programı için kurulum dosyasını (.exe, .msi) bu pencereye sürükle.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            } else {
                ProgramTiles(items: items, bottle: bottle)
                    .padding(.horizontal, -8)
            }
        }
        .padding(20)
    }
}

private struct ProgramTiles: View {
    let items: [ProgramItem]
    let bottle: Bottle
    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(items) { item in
                ProgramTile(item: item, bottle: bottle)
            }
        }
    }
}

private struct ProgramTile: View {
    @Environment(AppModel.self) private var model
    let item: ProgramItem
    let bottle: Bottle
    @State private var icon: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                } else {
                    // Simgesi okunamayan programlar için genel simge.
                    Image(systemName: symbol)
                        .font(.system(size: 36, weight: .light))
                        .frame(width: 64, height: 64)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .frame(width: 64, height: 64)
            .task(id: item.id) { icon = await model.icon(for: item, in: bottle) }
            Text(item.name)
                .font(.callout)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.launch(item) }
        .contextMenu {
            Button("Aç") { model.launch(item) }
            Button("Finder'da Göster") { model.reveal(item) }
            if isRemovable {
                Divider()
                Button("Listeden Kaldır") { model.removeFromList(item) }
            }
        }
        .help(item.name)
    }

    /// Tarifin başlatıcısı ve Epic oyunları elle kaldırılmaz (oyun Epic'ten kaldırılınca listeden düşer).
    private var isRemovable: Bool {
        switch item.source {
        case .recipe, .epicGame: false
        case .pinned, .shortcut: true
        }
    }

    private var symbol: String {
        switch item.source {
        case .recipe: "star.square"
        case .pinned: "pin.square"
        case .epicGame: "gamecontroller"
        case let .shortcut(shortcut):
            if case .steamURL = shortcut.kind { "gamecontroller" } else { "app" }
        }
    }
}
