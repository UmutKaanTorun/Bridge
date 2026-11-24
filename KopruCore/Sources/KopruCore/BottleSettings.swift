import Foundation

/// Bir bottle'ın Köprü ayarları.
///
/// Sanal masaüstü (`explorer /desktop`) ayarı kaldırıldı: Wine'ın Mac sürücüsünde sanal masaüstü yok
/// (`CreateDesktop` yazılmamış), tek Mac penceresi açılmıyor, istenen boyut da uygulanmıyordu; yalnız yan
/// etkileri kalıyordu (çalışma alanı menü çubuğunu saymıyor, tam ekranda fare pencereye kilitlenmiyor,
/// çözünürlük değişikliği yalandan "başarılı"). Eski kopru.json'lardaki `virtualDesktop` alanı yok sayılır.
public struct BottleSettings: Codable, Hashable, Sendable {
    /// WINEMSYNC: Mach semaforlarıyla senkronizasyon; oyunlarda wineserver yükünü azaltır.
    /// Aynı bottle'daki bütün süreçler aynı değerle başlamalı.
    public var msync: Bool
    /// Metal HUD (kare hızı göstergesi).
    public var fpsHud: Bool
    /// DXMT yerine Wine'ın kendi Direct3D'siyle (wined3d) açılacak programların exe adları (ör. "Launcher.exe").
    /// Bottle'daki öteki programlar DXMT'de kalır. Motor bunu `Engine.wined3dProgramsVariable` ile alır;
    /// wined3d'nin OpenGL kullanması için tarif ayrıca `AppDefaults\<exe>\Direct3D\renderer=gl` yazar.
    /// Eski kopru.json dosyalarında yoktur.
    public var wined3dPrograms: [String]?
    /// DXMT'nin MetalFX uzamsal ölçekleyicisi (2×): oyun aynı çözünürlükte çizer, çıktı Retina'ya büyütülür.
    /// Yalnız DXMT'den geçen programlar (D3D10/11). Motor bunu `Engine.metalFXVariable` ile alır.
    /// Eski kopru.json dosyalarında yoktur; nil = kapalı.
    public var metalFXUpscale: Bool?
    /// Rosetta'nın AVX/AVX2'yi programlara bildirmesi (`Engine.advertiseAVXVariable`). nil = kapalı.
    public var advertiseAVX: Bool?

    public init(msync: Bool = true, fpsHud: Bool = false, wined3dPrograms: [String]? = nil,
                metalFXUpscale: Bool? = nil, advertiseAVX: Bool? = nil) {
        self.msync = msync
        self.fpsHud = fpsHud
        self.wined3dPrograms = wined3dPrograms
        self.metalFXUpscale = metalFXUpscale
        self.advertiseAVX = advertiseAVX
    }

    public static let `default` = BottleSettings()

    /// Bu ayarlar bottle'daki bütün süreçlerde aynı olmalı: MSync (wineserver) ve AVX (Wine işlemci bilgisini
    /// wineserver açılırken bir kez doldurur; sonradan bayrakla açılan program CPUID'de AVX görür ama
    /// IsProcessorFeaturePresent 0 döner). Biri değişirse açık bottle durdurulur.
    public func requiresRestart(comparedTo old: BottleSettings) -> Bool {
        msync != old.msync || (advertiseAVX ?? false) != (old.advertiseAVX ?? false)
    }
}
