import KopruCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Windows kurulum dosyaları (.exe, .msi).
    static let windowsInstallers: [UTType] = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
}

/// "Kur" penceresi: tarif listesi → tarif onayı, ya da listede olmayan program.
struct InstallSheet: View {
    enum Start: Identifiable, Hashable {
        case catalog
        case unlisted(URL)

        var id: String {
            switch self {
            case .catalog: "catalog"
            case let .unlisted(url): url.path
            }
        }
    }

    private enum Page: Hashable {
        case catalog
        case recipe(Recipe)
        case unlisted(URL)
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var page: Page
    @State private var query = ""
    @State private var selection: Recipe.ID?
    @State private var bottleName = ""
    @State private var targetBottleID: Bottle.ID?
    @State private var pickFile = false

    init(start: Start) {
        switch start {
        case .catalog:
            _page = State(initialValue: .catalog)
        case let .unlisted(url):
            _page = State(initialValue: .unlisted(url))
            _bottleName = State(initialValue: url.deletingPathExtension().lastPathComponent)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch page {
            case .catalog: catalogPage
            case let .recipe(recipe): recipePage(recipe)
            case let .unlisted(file): unlistedPage(file)
            }
        }
        .padding(20)
        .frame(width: 500, height: 420)
        .fileImporter(isPresented: $pickFile, allowedContentTypes: UTType.windowsInstallers) { result in
            if case let .success(url) = result {
                bottleName = url.deletingPathExtension().lastPathComponent
                page = .unlisted(url)
            }
        }
    }

    private var catalogPage: some View {
        Group {
            Text("Program Kur").font(.title2.bold())
            TextField("Program ara…", text: $query)
                .textFieldStyle(.roundedBorder)
            List(selection: $selection) {
                ForEach(model.catalog.search(query)) { recipe in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.name).font(.headline)
                            Text(recipe.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(recipe.rating.label)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                    .tag(recipe.id)
                }
                Button {
                    pickFile = true
                } label: {
                    Label("Listede olmayan program…", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.link)
            }
            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Devam") {
                    if let recipe = model.catalog.recipe(id: selection) {
                        bottleName = recipe.bottle.defaultName
                        page = .recipe(recipe)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
    }

    private func recipePage(_ recipe: Recipe) -> some View {
        Group {
            Text("\(recipe.name) kurulacak").font(.title2.bold())
            Text(recipe.summary).foregroundStyle(.secondary)
            Form {
                TextField("Bottle adı", text: $bottleName)
                nameWarning
            }
            Spacer()
            HStack {
                Button("Geri") { page = .catalog }
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Kur") {
                    model.installRecipe(recipe, bottleName: bottleName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.isNameAvailable(bottleName))
            }
        }
    }

    private func unlistedPage(_ file: URL) -> some View {
        Group {
            Text("Listede olmayan program").font(.title2.bold())
            Label(file.lastPathComponent, systemImage: "doc").foregroundStyle(.secondary)
            Form {
                Picker("Nereye kurulsun", selection: $targetBottleID) {
                    Text("Yeni bottle").tag(Bottle.ID?.none)
                    ForEach(model.bottles) { bottle in
                        Text(bottle.info.name).tag(Bottle.ID?.some(bottle.id))
                    }
                }
                if targetBottleID == nil {
                    TextField("Bottle adı", text: $bottleName)
                    nameWarning
                }
            }
            Text("Windows kurulum penceresi açılacak; kurulumu oradan bitir. Kurulum kapanınca programlar listeye eklenir.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                Button("Geri") { page = .catalog }
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Kur") {
                    let existing = targetBottleID.flatMap { id in model.bottles.first { $0.id == id } }
                    model.installUnlisted(file: file, target: existing.map { .existing($0) } ?? .newBottle(bottleName))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(targetBottleID == nil && !model.isNameAvailable(bottleName))
            }
        }
    }

    @ViewBuilder
    private var nameWarning: some View {
        if !bottleName.trimmingCharacters(in: .whitespaces).isEmpty && !model.isNameAvailable(bottleName) {
            Text("Bu adla bir bottle var.").font(.caption).foregroundStyle(.red)
        }
    }
}
