import KopruCore
import SwiftUI

struct BottleSidebar: View {
    @Environment(AppModel.self) private var model
    @State private var askNewBottle = false
    @State private var newBottleName = ""
    @State private var pickImportFolder = false
    @State private var importRequest: ImportRequest?

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            Label("Program kur", systemImage: "plus.circle")
                .tag(SidebarItem.install)
            Section("Bottle'lar") {
                ForEach(model.bottles) { bottle in
                    HStack {
                        Label(bottle.info.name, systemImage: "shippingbox")
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
