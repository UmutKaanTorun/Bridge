import AppKit
import KopruCore
import SwiftUI

struct BottleSettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    @State private var name: String
    @State private var msync: Bool
    @State private var fpsHud: Bool
    @State private var metalFX: Bool
    @State private var avx: Bool
    @State private var confirmDelete = false

    init(bottle: Bottle) {
        self.bottle = bottle
        let settings = bottle.info.settings
        _name = State(initialValue: bottle.info.name)
        _msync = State(initialValue: settings.msync)
        _fpsHud = State(initialValue: settings.fpsHud)
        _metalFX = State(initialValue: settings.metalFXUpscale ?? false)
        _avx = State(initialValue: settings.advertiseAVX ?? false)
    }

    private var settings: BottleSettings {
        // Pencerede gösterilmeyen ayarlar (ör. tarifin wined3d programları) olduğu gibi kalır.
        var settings = bottle.info.settings
        settings.msync = msync
        settings.fpsHud = fpsHud
        settings.metalFXUpscale = metalFX
        settings.advertiseAVX = avx
        return settings
    }

    private var saved: BottleSettings { bottle.info.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bottle Ayarları").font(.title2.bold())
            Form {
                Section {
                    TextField("Ad", text: $name)
                    Toggle("MSync (oyunlarda daha akıcı)", isOn: $msync)
                    if msync != saved.msync {
                        Text("Kaydedince bottle'daki açık programlar kapatılacak.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Toggle("FPS göstergesi", isOn: $fpsHud)
                }
                Section("Performans") {
                    Toggle(isOn: $metalFX) {
                        Text("Keskin görüntü (MetalFX)")
                        Text("DirectX 11 oyunlarını MetalFX ile Retina çözünürlüğe büyütür. Retina olmayan ekranda kapalı bırakın.")
                    }
                    // MetalFX'i her swapchain kendi sürecinden okur: açık programlar eski değerle sürer.
                    if metalFX != (saved.metalFXUpscale ?? false) {
                        Text("Açık programlar yeniden açılınca geçerli olur.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle(isOn: $avx) {
                        Text("AVX desteği")
                        Text("AVX isteyen oyunlar için. Bazı oyunlar yavaşlayabilir.")
                    }
                    // AVX bütün süreçlerde aynı olmalı (BottleSettings.requiresRestart); AppModel.update bottle'ı durdurur.
                    if avx != (saved.advertiseAVX ?? false) {
                        Text("Kaydedince bottle'daki açık programlar kapatılacak.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
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
        .frame(width: 520, height: 600)
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
