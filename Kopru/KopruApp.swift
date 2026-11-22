import SwiftUI

@main
struct KopruApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Bridge") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1040, minHeight: 560)
        }
        // İlk açılış boyutu: platformlar iki sütun.
        .defaultSize(width: 1280, height: 800)
        .commands {
            // Dosya menüsü: tek pencereli uygulama; "Yeni Pencere" yerine bottle komutları.
            CommandGroup(replacing: .newItem) {
                Button("Boş Bottle…") { model.isAskingNewBottle = true }
                    .keyboardShortcut("n")
                    .disabled(!model.isReady || model.isInstallRunning)
                Button("Bottle İçe Aktar…") { model.isPickingImportFolder = true }
                    .disabled(!model.isReady)
            }
            // Düzen menüsündeki metin "Bul" grubu yerine: ⌘F Kur sayfasında arar.
            CommandGroup(replacing: .textEditing) {
                Button("Programlarda Ara") { model.focusSearch() }
                    .keyboardShortcut("f")
            }
        }
    }
}
