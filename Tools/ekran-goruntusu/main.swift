import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// README'deki tanıtım ekran görüntüleri için yardımcı; Scripts/ekran-goruntuleri.sh derleyip kullanır.
//
//   ekran-goruntusu pencere <pid>
//       → "<pencere-id> <genişlik>x<yükseklik>": sürecin en büyük normal penceresi (punto)
//   ekran-goruntusu yakala <pencere-id> <çıktı.png>
//       → pencereyi gölgesiz yakalar. Arama alanında yanıp sönen imleç görünmeyen kareyi seçer.
//         Pencere etkin değilse (gri trafik ışıkları) çıkış kodu 2.
//   ekran-goruntusu yerlestir <pencere.png> <çıktı.png> <acik|koyu>
//       → pencereyi ölçeklemeden 3840x2160 tuvalin ortasına koyar: simgenin degradesi, yumuşak gölge.

let arguments = CommandLine.arguments

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("ekran-goruntusu: \(message)\n".utf8))
    exit(code)
}

func loadImage(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("okunamadı: \(path)") }
    return image
}

func writePNG(_ image: CGImage, to path: String) {
    guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                            UTType.png.identifier as CFString, 1, nil) else {
        fail("yazılamadı: \(path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("yazılamadı: \(path)") }
}

/// Görüntünün sRGB RGBA8 pikselleri (sol üstten satır satır).
struct Pixels {
    let width: Int, height: Int
    private let bytes: [UInt8]

    init(_ image: CGImage) {
        let width = image.width, height = image.height
        self.width = width
        self.height = height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        buffer.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        bytes = buffer
    }

    func rgb(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        let i = (y * width + x) * 4
        return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
    }

    /// Program kur sayfasındaki arama alanında imlecin (vurgu mavisi dikey çizgi) piksel sayısı.
    /// Alan sağa yaslı; bölge pencerenin sağ kenarına ve üstüne göre (2x piksel).
    var caretPixels: Int {
        var count = 0
        for y in 140..<min(240, height) {
            for x in max(0, width - 700)..<max(0, width - 480) {
                let (r, g, b) = rgb(x, y)
                if b > 200, r < 110, g > 70, g < 180 { count += 1 }
            }
        }
        return count
    }

    /// Kapat düğmesi kırmızıysa pencere etkin (önde); etkin değilken gridir.
    var isActiveWindow: Bool {
        let (r, g, _) = rgb(52, 52)
        return r > 200 && g < 130
    }
}

func largestWindow(of pid: pid_t) -> (id: Int, width: Int, height: Int)? {
    let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    var best: (id: Int, width: Int, height: Int)?
    for window in windows {
        guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
              (window[kCGWindowLayer as String] as? Int) == 0,
              let id = window[kCGWindowNumber as String] as? Int,
              let bounds = window[kCGWindowBounds as String] as? [String: Double],
              let width = bounds["Width"].map(Int.init), let height = bounds["Height"].map(Int.init)
        else { continue }
        if best == nil || width * height > best!.width * best!.height { best = (id, width, height) }
    }
    return best
}

func capture(window id: String, to path: String) {
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("ekran-goruntusu-\(getpid()).png").path
    var best: (caret: Int, image: CGImage)?
    for _ in 0..<10 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l\(id)", temporary]
        do { try process.run() } catch { fail("screencapture çalışmadı: \(error.localizedDescription)") }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { fail("screencapture başarısız (Ekran Kaydı izni var mı?)") }
        let image = loadImage(temporary)
        let caret = Pixels(image).caretPixels
        if best == nil || caret < best!.caret { best = (caret, image) }
        if caret == 0 { break }
        Thread.sleep(forTimeInterval: 0.23)
    }
    try? FileManager.default.removeItem(atPath: temporary)
    guard let best else { fail("yakalanamadı") }
    writePNG(best.image, to: path)
    let active = Pixels(best.image).isActiveWindow
    print("\(best.image.width)x\(best.image.height) imleç=\(best.caret) etkin=\(active ? "evet" : "hayır")")
    if !active { exit(2) }
}

func compose(window path: String, to output: String, dark: Bool) {
    let canvas = (width: 3840, height: 2160)
    let window = loadImage(path)
    guard window.width <= canvas.width, window.height <= canvas.height else {
        fail("pencere tuvalden büyük: \(window.width)x\(window.height)")
    }
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: sRGB, components: [CGFloat(hex >> 16 & 0xFF) / 255, CGFloat(hex >> 8 & 0xFF) / 255,
                                               CGFloat(hex & 0xFF) / 255, alpha])!
    }
    // Koyu: uygulama simgesinin degradesi (Kopru/AppIcon.icon/icon.json). Açık: aynı morun açık tonları.
    let top: UInt32 = dark ? 0x2B1F66 : 0xF1EEFF
    let bottom: UInt32 = dark ? 0x0A0720 : 0xD3CBF6
    let shadow = dark ? color(0x000000, alpha: 0.60) : color(0x2B1F66, alpha: 0.30)

    guard let context = CGContext(data: nil, width: canvas.width, height: canvas.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fail("tuval oluşturulamadı") }
    // Dikey degrade satır satır, her satır tek renk: CGGradient titreşimli (dithering) çizer, PNG 4 kat büyür.
    for row in 0..<canvas.height {
        let t = CGFloat(row) / CGFloat(canvas.height - 1)
        let channels = [16, 8, 0].map { shift -> CGFloat in
            let a = CGFloat(top >> UInt32(shift) & 0xFF), b = CGFloat(bottom >> UInt32(shift) & 0xFF)
            return (a + (b - a) * t).rounded() / 255
        }
        context.setFillColor(CGColor(colorSpace: sRGB, components: channels + [1])!)
        context.fill(CGRect(x: 0, y: canvas.height - 1 - row, width: canvas.width, height: 1))
    }
    // Pencere ortada, 20 px yukarıda; gölge 36 px aşağıda. CoreGraphics'te y yukarı doğru artar.
    let x = (canvas.width - window.width) / 2
    let topInset = (canvas.height - window.height) / 2 - 20
    let frame = CGRect(x: x, y: canvas.height - topInset - window.height, width: window.width, height: window.height)
    context.setShadow(offset: CGSize(width: 0, height: -36), blur: 128, color: shadow)
    context.draw(window, in: frame)
    guard let image = context.makeImage() else { fail("tuval okunamadı") }
    writePNG(image, to: output)
}

switch (arguments.count, arguments.dropFirst().first) {
case (3, "pencere"):
    guard let pid = pid_t(arguments[2]), let window = largestWindow(of: pid) else { fail("pencere bulunamadı", code: 3) }
    print("\(window.id) \(window.width)x\(window.height)")
case (4, "yakala"):
    capture(window: arguments[2], to: arguments[3])
case (5, "yerlestir") where ["acik", "koyu"].contains(arguments[4]):
    compose(window: arguments[2], to: arguments[3], dark: arguments[4] == "koyu")
default:
    fail("""
    kullanım:
      ekran-goruntusu pencere <pid>
      ekran-goruntusu yakala <pencere-id> <çıktı.png>
      ekran-goruntusu yerlestir <pencere.png> <çıktı.png> <acik|koyu>
    """)
}
