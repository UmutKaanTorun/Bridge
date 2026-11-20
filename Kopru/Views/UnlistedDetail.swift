import KopruCore
import SwiftUI

/// Listede olmayan kurulum dosyası: nereye kurulacağı ve ilerleme.
struct UnlistedDetail: View {
    @Environment(AppModel.self) private var model
    let file: URL
    private let fileSize: String
    @State private var targetBottleID: Bottle.ID?
    @State private var bottleName: String

    init(file: URL, defaultBottleID: Bottle.ID?) {
        self.file = file
        let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        fileSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        _targetBottleID = State(initialValue: defaultBottleID)
        _bottleName = State(initialValue: file.deletingPathExtension().lastPathComponent)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 13) {
                        Image(systemName: "doc")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.lastPathComponent).font(.title3.bold()).lineLimit(2)
                            Text("Listede olmayan program · \(fileSize)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Bu program için Köprü'de hazır ayar yok; genel Windows 10 ayarlarıyla kurulur.")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 14)
                    PanelSectionTitle("Ne olacak")
                    step(1, "Windows kurulum penceresi açılır", detail: "Kurulumu oradan bitirirsin")
                    step(2, "Programlar listeye eklenir", detail: "Kurulum penceresi kapanınca")
                }
                .padding(EdgeInsets(top: 26, leading: 22, bottom: 16, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
                .padding(EdgeInsets(top: 14, leading: 22, bottom: 18, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            // Önerilen bottle o arada silinmiş olabilir; o zaman yeni bottle önerilir.
            if let id = targetBottleID, !model.bottles.contains(where: { $0.id == id }) {
                targetBottleID = nil
            }
        }
    }

    private func step(_ number: Int, _ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(number, format: .number)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var footer: some View {
        if let progress = model.install, progress.source == .unlisted(file) {
            InstallProgressPanel(progress: progress)
        } else if model.isInstallRunning {
            RunningInstallNotice()
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Picker("Nereye kurulsun", selection: $targetBottleID) {
                    Text("Yeni bottle").tag(Bottle.ID?.none)
                    ForEach(model.bottles) { bottle in
                        Text(bottle.info.name).tag(Bottle.ID?.some(bottle.id))
                    }
                }
                if targetBottleID == nil {
                    Text("Bottle adı").font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                    TextField("Bottle adı", text: $bottleName).labelsHidden()
                    if !bottleName.trimmingCharacters(in: .whitespaces).isEmpty && !model.isNameAvailable(bottleName) {
                        Text("Bu adla bir bottle var.").font(.caption).foregroundStyle(.red)
                    }
                }
                HStack {
                    Button("Vazgeç") { model.unlistedFile = nil }
                    Spacer()
                    Button("Kur") { install() }
                        .defaultActionUnlessSearching()
                        .disabled(targetBottleID == nil && !model.isNameAvailable(bottleName))
                }
                .padding(.top, 7)
            }
        }
    }

    private func install() {
        let existing = targetBottleID.flatMap { id in model.bottles.first { $0.id == id } }
        model.installUnlisted(file: file, target: existing.map { .existing($0) } ?? .newBottle(bottleName))
    }
}
