import KopruCore
import SwiftUI

/// Kenar çubuğundaki "Program kur": arama, kategoriler, kartlar ve sağ panel.
struct InstallPage: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var category: RecipeCategory?
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 10, alignment: .top)]

    var body: some View {
        let sections = model.catalog.sections(matching: query, category: category)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                filterRow
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                if sections.isEmpty {
                    emptyResult
                } else {
                    grid("Kurulmaya hazır", note: "Köprü ekibi test etti", entries: sections.ready)
                    grid("Yakında", note: "Test ediliyor", entries: sections.upcoming)
                }
            }
            .padding(EdgeInsets(top: 26, leading: 28, bottom: 28, trailing: 28))
        }
        .navigationTitle("Program kur")
        .inspector(isPresented: .constant(true)) {
            InstallInspector()
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .onAppear {
            if model.selectedEntryID == nil, model.unlistedFile == nil {
                model.selectedEntryID = (sections.ready.first ?? sections.upcoming.first)?.id
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Program kur").font(.largeTitle.bold())
            Spacer()
            searchField.frame(width: 280)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Program ara", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("Aramayı temizle")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private var chips: some View {
        HStack(spacing: 6) {
            CategoryChip(title: "Tümü", count: model.catalog.count(in: nil), isOn: category == nil) {
                category = nil
            }
            ForEach(model.catalog.categories, id: \.self) { item in
                CategoryChip(title: item.label, count: model.catalog.count(in: item), isOn: category == item) {
                    category = item
                }
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) { chips }
    }

    @ViewBuilder
    private func grid(_ title: LocalizedStringKey, note: LocalizedStringKey, entries: [CatalogEntry]) -> some View {
        if !entries.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.headline)
                Text(note).font(.callout).foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(entries) { entry in
                    CatalogCard(entry: entry,
                                isSelected: model.unlistedFile == nil && model.selectedEntryID == entry.id)
                        .onTapGesture(count: 2) { openIfInstalled(entry) }
                        .onTapGesture { model.selectEntry(entry.id) }
                }
            }
            .padding(.bottom, 26)
        }
    }

    private func openIfInstalled(_ entry: CatalogEntry) {
        model.selectEntry(entry.id)
        if let bottle = model.installedBottle(for: entry) { model.launchRecipe(in: bottle) }
    }

    private var emptyResult: some View {
        VStack(spacing: 6) {
            Text(query.isEmpty ? "Katalogda program yok" : "“\(query)” için hazır tarif yok")
                .font(.headline)
            Text("Kurulum dosyan varsa pencereye sürükle; Köprü onu yeni bir bottle'a kurar.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(24)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        }
    }
}

/// Kategori kapsülü; seçiliyken dolu.
private struct CategoryChip: View {
    let title: String
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text(count, format: .number).opacity(0.6)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
            .background(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
