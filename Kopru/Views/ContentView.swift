import KopruCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var unlistedStart: InstallSheet.Start?
    @State private var showSettings = false
    @State private var pickExecutable = false
    @State private var executableToRun: URL?

    var body: some View {
        NavigationSplitView {
            BottleSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            detail
        }
        .toolbar { toolbar }
        .onChange(of: model.selection) { model.rescan() }
        .dropDestination(for: URL.self) { urls, _ in
            guard model.isReady, let file = urls.first,
                  ["exe", "msi"].contains(file.pathExtension.lowercased()) else { return false }
            unlistedStart = .unlisted(file)
            return true
        }
        .sheet(item: $unlistedStart) { start in
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

    /// Tarif kurulumları Kur sayfasının panelinde; diğerleri (listede olmayan, boş bottle) bu sheet'te.
    private var progressBinding: Binding<InstallProgress?> {
        Binding(get: {
                    guard unlistedStart == nil, let progress = model.install else { return nil }
                    if case .recipe = progress.source { return nil }
                    return progress
                },
                set: { if $0 == nil { model.install = nil } })
    }

    @ViewBuilder
    private var detail: some View {
        if let problem = model.startupProblem {
            StartupProblemView(problem: problem)
        } else if model.isBottlePage, let bottle = model.selectedBottle {
            ProgramGrid(bottle: bottle)
        } else {
            InstallPage()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.isBottlePage {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.showInstallPage() } label: { Label("Kur", systemImage: "plus.circle") }
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
}
