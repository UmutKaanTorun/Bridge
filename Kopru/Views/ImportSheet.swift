import KopruCore
import SwiftUI

struct ImportRequest: Identifiable {
    let id = UUID()
    let folder: URL
}

/// Var olan bir Wine bottle'ını Köprü'ye taşır.
struct ImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let folder: URL
    @State private var name: String

    init(folder: URL) {
        self.folder = folder
        _name = State(initialValue: folder.lastPathComponent)
    }

    var body: some View {
        let isBottle = BottleStore.isWineBottle(folder)
        VStack(alignment: .leading, spacing: 12) {
            Text("Bottle İçe Aktar").font(.title2.bold())
            Label(folder.path, systemImage: "folder")
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            if isBottle {
                Form {
                    TextField("Bottle adı", text: $name)
                }
                Text("Klasör Köprü'nün bottle klasörüne taşınır; eski yolu kullanan betikler (ör. steam26.sh) onu artık bulamaz. Bottle'daki açık Windows programları kapatılır.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else {
                Text("Bu bir Wine bottle'ı değil: içinde system.reg ve drive_c olmalı.")
                    .foregroundStyle(.red)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("İçe Aktar") {
                    model.importBottle(from: folder, name: name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isBottle || !model.isNameAvailable(name))
            }
        }
        .padding(20)
        .frame(width: 480, height: 300)
    }
}
