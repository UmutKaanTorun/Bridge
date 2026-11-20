import SwiftUI

@main
struct KopruApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Köprü") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1040, minHeight: 560)
        }
        .commands {
            // Düzen menüsündeki metin "Bul" grubu yerine: ⌘F Kur sayfasında arar.
            CommandGroup(replacing: .textEditing) {
                Button("Programlarda Ara") { model.focusSearch() }
                    .keyboardShortcut("f")
            }
        }
    }
}
