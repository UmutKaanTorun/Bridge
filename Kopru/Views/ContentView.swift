import KopruCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var installStart: InstallSheet.Start?
    @State private var showSettings = false
    @State private var pickExecutable = false
    @State private var executableToRun: URL?

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            BottleSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            detail
        }
        .toolbar { toolbar }
        .onChange(of: model.selectedBottleID) { model.rescan() }
        .dropDestination(for: URL.self) { urls, _ in
            guard model.isReady, let file = urls.first,
                  ["exe", "msi"].contains(file.pathExtension.lowercased()) else { return false }
            installStart = .unlisted(file)
            return true
        }
        .sheet(item: $installStart) { start in
            InstallSheet(start: start)
        }
        .sheet(item: progressBinding) { _ in
            InstallProgressView()
        }
        .sheet(isPresented: $showSettings) {
            if let bottle = model.selectedBottle {
                BottleSettingsSheet(bottle: bottle)
            }
        }
        .fileImporter(isPresented: $pickExecutable, allowedContentTypes: UTType.windowsInstallers) { result in
            if case let .success(url) = result { executableToRun = url }
        }
        .fileDialogDefaultDirectory(model.selectedBottle?.driveC)
        .confirmationDialog("Program çalıştırılsın mı?",
                            isPresented: Binding(get: { executableToRun != nil }, set: { if !$0 { executableToRun = nil } }),
                            presenting: executableToRun) { url in
            Button("Çalıştır") { model.runExecutable(url, pin: false) }
            Button("Çalıştır ve listeye ekle") { model.runExecutable(url, pin: true) }
            Button("Vazgeç", role: .cancel) {}
        } message: { url in
            Text(url.lastPathComponent)
        }
        .alert(model.alert?.title ?? "",
               isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
               presenting: model.alert) { alert in
            if let log = alert.logURL {
                Button("Günlüğü Göster") { model.openLog(log) }
            }
            Button("Tamam", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    /// İlerleme penceresi yalnızca Kur penceresi kapalıyken gösterilir (Kur'a basınca o kapanır, bu açılır).
    private var progressBinding: Binding<InstallProgress?> {
        Binding(get: { installStart == nil ? model.install : nil },
                set: { if $0 == nil { model.install = nil } })
    }

    @ViewBuilder
    private var detail: some View {
        if let problem = model.startupProblem {
            StartupProblemView(problem: problem)
        } else if let bottle = model.selectedBottle {
            ProgramGrid(bottle: bottle)
        } else {
            ContentUnavailableView {
                Label("Henüz bottle yok", systemImage: "shippingbox")
            } description: {
                Text("Kur'a bas ya da bir kurulum dosyasını (.exe, .msi) bu pencereye sürükle.")
            } actions: {
                Button("Program Kur") { installStart = .catalog }
                    .disabled(!model.isReady)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { installStart = .catalog } label: { Label("Kur", systemImage: "plus.circle") }
                .disabled(!model.isReady)
            Button { model.openDriveC() } label: { Label("C: Sürücüsü", systemImage: "internaldrive") }
                .disabled(model.selectedBottle == nil)
            Button { pickExecutable = true } label: { Label("Program Çalıştır…", systemImage: "play") }
                .disabled(model.selectedBottle == nil || !model.isReady)
            Button { model.stopSelected() } label: { Label("Durdur", systemImage: "stop.circle") }
                .disabled(model.selectedBottle == nil || !model.isReady)
            Button { showSettings = true } label: { Label("Ayarlar", systemImage: "gearshape") }
                .disabled(model.selectedBottle == nil)
        }
    }
}
