import KopruCore
import SwiftUI
import UniformTypeIdentifiers

/// Kenar çubuğundaki "Program kur": oyun platformları. Satıra tıklamak indirip kurar.
struct InstallPage: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 36, alignment: .top)]

    var body: some View {
        @Bindable var model = model
        let platforms = model.catalog.platforms(matching: query)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                HiddenUnlistedInstallBanner()
                    .padding(.top, 14)
                sectionTitle
                    .padding(.top, 22)
                    .padding(.bottom, 6)
                if platforms.isEmpty {
                    emptyResult.padding(.top, 10)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                        ForEach(platforms) { recipe in
                            PlatformRow(recipe: recipe)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: 26, leading: 28, bottom: 28, trailing: 28))
        }
        .navigationTitle("Program kur")
        .modifier(HideToolbarTitle())
        .task(id: model.wantsSearchFocus) {
            guard model.wantsSearchFocus else { return }
            // Sayfa yeni açıldıysa alan odak alabilsin diye bir an bekle.
            try? await Task.sleep(for: .milliseconds(50))
            searchFocused = true
            model.wantsSearchFocus = false
        }
        .fileImporter(isPresented: $model.isPickingInstaller, allowedContentTypes: UTType.windowsInstallers) { result in
            if case let .success(url) = result { model.showInstallPage(unlisted: url) }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Program kur").font(.largeTitle.bold()).lineLimit(1)
            Spacer()
            searchField.frame(minWidth: 180, maxWidth: 280)
        }
    }

    private var sectionTitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                sectionLabel
                Spacer(minLength: 0)
                unlistedLink
            }
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel
                unlistedLink
            }
        }
        .padding(.horizontal, 12)
    }

    private var sectionLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Oyun platformları").font(.title2.weight(.semibold))
            Text("Tıkla, Köprü indirip kursun").font(.callout).foregroundStyle(.secondary)
        }
        .fixedSize()
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Program ara", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
                .onExitCommand { query = "" }
            if query.isEmpty {
                Text("⌘F").font(.caption).foregroundStyle(.tertiary)
            } else {
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

    private var unlistedLink: some View {
        HStack(spacing: 4) {
            Text("Listede yok mu?").foregroundStyle(.secondary)
            Button("Kurulum dosyası seç…") { model.isPickingInstaller = true }
                .buttonStyle(.link)
        }
        .fixedSize()
        .help("Kurulum dosyasını (.exe, .msi) pencereye de sürükleyebilirsin")
    }

    private var emptyResult: some View {
        VStack(spacing: 6) {
            Text(query.isEmpty ? "Katalogda platform yok" : "“\(query)” için hazır tarif yok")
                .font(.headline)
            Text("Kurulum dosyan varsa pencereye sürükle; Köprü onu yeni bir bottle'a kurar.")
                .foregroundStyle(.secondary)
            Button("Kurulum dosyası seç…") { model.isPickingInstaller = true }
                .padding(.top, 6)
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

/// Listede olmayan dosyanın kurulum penceresi gizlendiyse sayfanın üstünde ona dönüş şeridi.
private struct HiddenUnlistedInstallBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let progress = model.install, case let .unlisted(file) = progress.source, model.unlistedFile == nil {
            HStack(spacing: 8) {
                if progress.isActive {
                    ProgressView().controlSize(.small)
                } else if progress.failedStep != nil {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                Text(file.lastPathComponent).lineLimit(1).truncationMode(.middle)
                Text(progress.isActive ? "kuruluyor" : progress.failedStep != nil ? "kurulamadı" : "kuruldu")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Göster") { model.showInstallPage(unlisted: file) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// Araç çubuğundaki yinelenen başlığı gizler (macOS 15+; 14'te başlık kalır).
private struct HideToolbarTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
