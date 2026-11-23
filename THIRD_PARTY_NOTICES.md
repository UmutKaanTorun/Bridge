# Üçüncü taraf bileşenleri

Bridge'in Release derlemesi, Windows programlarını çalıştırmak için aşağıdaki açık kaynak bileşenleri uygulamanın içinde (`Bridge.app/Contents/Resources/Motor`) dağıtır. Her bileşen kendi lisansıyla gelir. Bridge'in [lisansı](LICENSE) bu lisansların size tanıdığı hakları kısıtlamaz. Aşağıdaki özet bilgi içindir; bağlayıcı olan, her projenin kendi lisans metnidir.

## Wine motoru

| Bileşen | Sürüm | Lisans | Kaynak |
|---|---|---|---|
| Wine (CrossOver'ın açık kaynak dağıtımı) | CrossOver 26.3.0, Wine 11.0 tabanlı | LGPL-2.1-or-later | [codeweavers.com/crossover/source](https://www.codeweavers.com/crossover/source) |
| DXMT (Metal üzerinden Direct3D 10/11) | 0.80 | LGPL-2.1-or-later | [github.com/3Shain/dxmt](https://github.com/3Shain/dxmt) |
| Wine Gecko | 2.47.4 | MPL-2.0 | [dl.winehq.org/wine/wine-gecko/2.47.4](https://dl.winehq.org/wine/wine-gecko/2.47.4/) |
| Wine Mono | 10.4.1 | Çoğunlukla MIT; Mono parçaları LGPL ya da MIT, bazı kitaplıklar Ms-PL ve zlib (projenin `COPYING` dosyası) | [dl.winehq.org/wine/wine-mono/10.4.1](https://dl.winehq.org/wine/wine-mono/10.4.1/) |

- Wine: Copyright © 1993–2026 the Wine project authors; CrossOver değişiklikleri © CodeWeavers, Inc.
- DXMT: Copyright © 2023–2026 Feifan He for CodeWeavers.

**Bridge'in Wine'a uyguladığı değişiklikler** [`Tools/motor-yamalari`](Tools/motor-yamalari/BENIOKU.md) altındadır ve Wine gibi LGPL-2.1-or-later lisanslıdır. Motor, CrossOver 26.3.0 kaynak kodu bu yamalarla derlenerek elde edilir.

## Motorun kullandığı kütüphaneler

Motor, MacPorts ile derlenmiş aşağıdaki kütüphaneleri `lib/` klasöründe taşır.

| Kütüphane | Lisans |
|---|---|
| MoltenVK | Apache-2.0 |
| SDL2 | Zlib |
| FreeType | FTL ya da GPL-2.0-or-later |
| GnuTLS | LGPL-2.1-or-later |
| Nettle (libnettle, libhogweed) | LGPL-3.0-or-later ya da GPL-2.0-or-later |
| GMP | LGPL-3.0-or-later ya da GPL-2.0-or-later |
| libtasn1 | LGPL-2.1-or-later |
| p11-kit | BSD-3-Clause |
| libidn2 | LGPL-3.0-or-later ya da GPL-2.0-or-later |
| libunistring | LGPL-3.0-or-later ya da GPL-2.0-or-later |
| libiconv (libcharset dahil) | LGPL-2.1-or-later |
| gettext (libintl) | LGPL-2.1-or-later |
| ICU | Unicode-3.0 |
| libxml2 | MIT |
| libxslt (libexslt dahil) | MIT |
| libffi | MIT |
| libinotify-kqueue | MIT |
| Brotli | MIT |
| zlib | Zlib |
| bzip2 | bzip2-1.0.6 |
| xz (liblzma) | 0BSD |
| LZ4 | BSD-2-Clause |
| Zstandard | BSD-3-Clause ya da GPL-2.0-only |
| libpng | libpng-2.0 |
| libpcap | BSD-3-Clause |
| macports-legacy-support | MIT; Apple kaynaklı parçalar APSL-2.0 |

Kütüphanelerin kaynak kodu kendi projelerinden ve [MacPorts](https://ports.macports.org) port tanımlarından edinilebilir.

## Ticari markalar

Steam, Epic Games, GOG Galaxy, Battle.net, EA App, Ubisoft Connect, Rockstar Games Launcher ve ekran görüntülerinde görünen oyunların adları ve simgeleri sahiplerinin ticari markalarıdır. Bridge bu şirketlerle bağlantılı değildir ve onlarca onaylanmamıştır.
