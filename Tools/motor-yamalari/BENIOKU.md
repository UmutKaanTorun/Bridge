# Motor yamaları

Köprü'nün Wine motoru CrossOver 26.3.0 kaynağından derleniyor (`~/WineBuild/kaynak-26.3.0/sources/wine`). Yamalar bu sırayla uygulanır (`patch -p1`):

| Sıra | Yama | Ne yapar | Köprü tarafı |
|---|---|---|---|
| 1 | `ntdll-dock-adi.patch` | Dock, Windows süreçlerini programın adıyla gösterir. | `Engine.appNameVariable` (`KOPRU_APP_NAME`) |
| 2 | `ntdll-program-basina-wined3d.patch` | Listedeki programlar DXMT yerine Wine'ın kendi Direct3D'siyle (`orijinal-grafik/`) açılır. | `BottleSettings.wined3dPrograms` → `KOPRU_WINED3D_EXE` |
| 3 | `ntdll-saat-dilimi.patch` | Aynı kurala uyan saat dilimlerinden Mac'inkine karşılık geleni seçer (İstanbul: Arab değil Turkey Standard Time). | Yok (macOS ICU'dan kendisi bulur) |

Üçü de yalnız `dlls/ntdll/unix/` dosyalarına dokunur; derleme `~/WineBuild/yapi-26.3.0`'da `make dlls/ntdll/ntdll.so`. Sonuç motora `lib/wine/x86_64-unix/ntdll.so` olarak kopyalanır; Release derlemesi motoru pakete alır (`Scripts/bundle-engine.sh`).
