# Motor yamaları

Köprü'nün Wine motoru CrossOver 26.3.0 kaynağından derleniyor (`~/WineBuild/kaynak-26.3.0/sources/wine`). Yamalar bu sırayla uygulanır (`patch -p1`):

| Sıra | Yama | Ne yapar | Köprü tarafı |
|---|---|---|---|
| 1 | `ntdll-dock-adi.patch` | Dock, Windows süreçlerini programın adıyla gösterir. | `Engine.appNameVariable` (`KOPRU_APP_NAME`) |
| 2 | `ntdll-program-basina-wined3d.patch` | Listedeki programlar DXMT yerine Wine'ın kendi Direct3D'siyle (`orijinal-grafik/`) açılır. | `BottleSettings.wined3dPrograms` → `KOPRU_WINED3D_EXE` |
| 3 | `ntdll-saat-dilimi.patch` | Aynı kurala uyan saat dilimlerinden Mac'inkine karşılık geleni seçer (İstanbul: Arab değil Turkey Standard Time). | Yok (macOS ICU'dan kendisi bulur) |
| 4 | `winemac-dock-gizle.patch` | `AppDefaults\<exe>\Mac Driver\ShowInDock="n"` olan program Dock'ta ayrı simge açmaz; pencereleri yine açılır ve odak alır (Accessory). Rockstar'ın penceresiz `Launcher.exe`'si yüzünden Dock'ta iki aynı simge çıkıyordu. | Tarifin `afterInstall` kayıt defteri eylemi (`rockstar.json`) |
| 5 | `wineserver-klasor-bildirimi.patch` | macOS'ta (inotify yok) Wine süreçlerinin wineserver üzerinden yaptığı oluşturma, silme, ad değiştirme ve yazılmış dosyanın kapanması klasör izleyicilerine (`ReadDirectoryChangesW`) olay olarak iletilir. Epic'in kurulum klasörü hazırlayıcısı bununla haberleşiyor; olay gelmeyince oyun kurulumu DP-06 veriyordu. | Yok |

İlk üçü yalnız `dlls/ntdll/unix/` dosyalarına dokunur; derleme `~/WineBuild/yapi-26.3.0`'da `make dlls/ntdll/ntdll.so`, sonuç motora `lib/wine/x86_64-unix/ntdll.so` olarak kopyalanır. Dördüncüsü `dlls/winemac.drv/` dosyalarına dokunur: `make dlls/winemac.drv/winemac.so` → `lib/wine/x86_64-unix/winemac.so` (yamasız yedek `~/WineBuild/yedek/winemac.so.yamasiz`). Beşincisi `server/` dosyalarına dokunur: `make server/wineserver` → motorun `bin/wineserver`'ı (yamasız yedek `~/WineBuild/yedek/wineserver.yamasiz`); çalışan bir Wine oturumu varken değiştirilmemeli, sunucu ve istemciler aynı derlemeden olmalı. Derleme `arch -x86_64` ile yapılır. Motordaki dosya, çalışan Wine süreçleri bozulmasın diye yerinde üzerine yazılmaz: önce yanına kopyalanır, sonra `mv` ile değiştirilir. Release derlemesi motoru pakete alır (`Scripts/bundle-engine.sh`).
