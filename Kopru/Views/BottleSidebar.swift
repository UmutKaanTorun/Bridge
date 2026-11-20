import KopruCore
import SwiftUI

struct BottleSidebar: View {
    @Environment(AppModel.self) private var model
    @State private var askNewBottle = false
    @State private var newBottleName = ""
    @State private var pickImportFolder = false
    @State private var importRequest: ImportRequest?

    var body: some View {
        // Boşluğa tıklamak seçimi silmesin (yoksa sayfa sessizce Kur'a döner).
        List(selection: Binding(get: { model.selection }, set: { if let item = $0 { model.selection = item } })) {
            Label("Program kur", systemImage: "plus.circle")
                .tag(SidebarItem.install)
            Section("Bottle'lar") {
                ForEach(model.bottles) { bottle in
                    HStack {
                        Label {
                            Text(bottle.info.name)
                        } icon: {
                            if let image = model.recipeIcon(forBottle: bottle) {
                                Image(nsImage: image).resizable().frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "shippingbox")
                            }
                        }
                        Spacer()
                        if model.isRunning(bottle) {
                            Circle().fill(.green).frame(width: 7, height: 7).help("Çalışıyor")
                        }
                    }
                    .tag(SidebarItem.bottle(bottle.id))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button("Boş Bottle…") {
                        newBottleName = ""
                        askNewBottle = true
                    }
                    .disabled(model.isInstallRunning)
                    Button("Bottle İçe Aktar…") { pickImportFolder = true }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!model.isReady)
                Spacer()
            }
            .padding(8)
        }
        .alert("Yeni Bottle", isPresented: $askNewBottle) {
            TextField("Ad", text: $newBottleName)
            Button("Oluştur") { model.createEmptyBottle(name: newBottleName) }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Boş bir Windows 10 ortamı oluşturulur.")
        }
        .fileImporter(isPresented: $pickImportFolder, allowedContentTypes: [.folder]) { result in
            if case let .success(folder) = result { importRequest = ImportRequest(folder: folder) }
        }
        .sheet(item: $importRequest) { request in
            ImportSheet(folder: request.folder)
        }
    }
}
