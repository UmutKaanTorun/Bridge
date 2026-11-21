import AppKit
import KopruCore
import SwiftUI

struct BottleSettingsSheet: View {
    private enum DesktopMode: Hashable { case off, auto, fixed }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    @State private var name: String
    @State private var msync: Bool
    @State private var desktopMode: DesktopMode
    @State private var width: Int
    @State private var height: Int
    @State private var fpsHud: Bool
    @State private var confirmDelete = false

    init(bottle: Bottle) {
        self.bottle = bottle
        let settings = bottle.info.settings
        _name = State(initialValue: bottle.info.name)
        _msync = State(initialValue: settings.msync)
        _fpsHud = State(initialValue: settings.fpsHud)
        switch settings.virtualDesktop {
        case .off:
            _desktopMode = State(initialValue: .off)
            _width = State(initialValue: 1280)
            _height = State(initialValue: 800)
        case .auto:
            _desktopMode = State(initialValue: .auto)
            _width = State(initialValue: 1280)
            _height = State(initialValue: 800)
        case let .fixed(width, height):
            _desktopMode = State(initialValue: .fixed)
            _width = State(initialValue: width)
            _height = State(initialValue: height)
        }
    }

    private var settings: BottleSettings {
        let desktop: VirtualDesktop = switch desktopMode {
        case .off: .off
        case .auto: .auto
        case .fixed: .fixed(width: max(640, width), height: max(480, height))
        }
        // Pencerede gösterilmeyen ayarlar (ör. tarifin wined3d programları) olduğu gibi kalır.
        var settings = bottle.info.settings
        settings.msync = msync
        settings.virtualDesktop = desktop
        settings.fpsHud = fpsHud
        return settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bottle Ayarları").font(.title2.bold())
            Form {
                TextField("Ad", text: $name)
                Toggle("MSync (oyunlarda daha akıcı)", isOn: $msync)
                if msync != bottle.info.settings.msync {
                    Text("Kaydedince bottle'daki açık programlar kapatılacak.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Picker("Sanal masaüstü", selection: $desktopMode) {
                    Text("Kapalı").tag(DesktopMode.off)
                    Text("Ekrana göre").tag(DesktopMode.auto)
                    Text("Elle").tag(DesktopMode.fixed)
                }
                if desktopMode == .fixed {
                    HStack {
                        TextField("Genişlik", value: $width, format: .number)
                        Text("×")
                        TextField("Yükseklik", value: $height, format: .number)
                    }
                }
                Toggle("FPS göstergesi", isOn: $fpsHud)
            }
            .formStyle(.grouped)
            HStack {
                Button("Windows Ayarları") { model.openWineSettings(bottle) }
                Button("C: Sürücüsünü Aç") { NSWorkspace.shared.open(bottle.driveC) }
                Spacer()
                Button("Bottle'ı Sil…", role: .destructive) { confirmDelete = true }
            }
            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Kaydet") {
                    model.update(bottle, name: name, settings: settings)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
        .confirmationDialog("“\(bottle.info.name)” silinsin mi?", isPresented: $confirmDelete) {
            Button("Çöp Kutusu'na Taşı", role: .destructive) {
                model.deleteBottle(bottle)
                dismiss()
            }
        } message: {
            Text("Bottle ve içine kurulan programlar Çöp Kutusu'na taşınır.")
        }
    }
}
