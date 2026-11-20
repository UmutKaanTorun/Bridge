import KopruCore
import SwiftUI

struct ProgramGrid: View {
    @Environment(AppModel.self) private var model
    let bottle: Bottle
    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)]

    var body: some View {
        let items = model.programs
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Bu bottle'da program yok", systemImage: "square.dashed")
                } description: {
                    Text("Kur'a bas ya da bir kurulum dosyasını (.exe, .msi) bu pencereye sürükle.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(items) { item in
                            ProgramTile(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(bottle.info.name)
        .navigationSubtitle(model.isRunning(bottle) ? "Çalışıyor" : "")
    }
}

private struct ProgramTile: View {
    @Environment(AppModel.self) private var model
    let item: ProgramItem

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .frame(width: 64, height: 64)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
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

    private var isRemovable: Bool {
        if case .recipe = item.source { false } else { true }
    }

    private var symbol: String {
        switch item.source {
        case .recipe: "star.square"
        case .pinned: "pin.square"
        case let .shortcut(shortcut):
            if case .steamURL = shortcut.kind { "gamecontroller" } else { "app" }
        }
    }
}
