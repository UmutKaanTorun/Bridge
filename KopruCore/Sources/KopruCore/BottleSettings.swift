import Foundation

/// Nokta cinsinden boyut.
public struct PixelSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Wine sanal masaüstü: bütün Windows pencereleri tek bir Mac penceresinin içinde çizilir.
public enum VirtualDesktop: Hashable, Sendable {
    case off
    /// Ana ekranın görünür alanından 40 nokta küçük.
    case auto
    case fixed(width: Int, height: Int)

    /// Masaüstü boyutu; kapalıysa nil.
    public func size(visibleScreen: PixelSize) -> PixelSize? {
        switch self {
        case .off:
            return nil
        case .auto:
            return PixelSize(width: max(640, visibleScreen.width - 40), height: max(480, visibleScreen.height - 40))
        case let .fixed(width, height):
            return PixelSize(width: width, height: height)
        }
    }
}

extension VirtualDesktop: Codable {
    private enum CodingKeys: String, CodingKey { case mode, width, height }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .mode) {
        case "off":
            self = .off
        case "auto":
            self = .auto
        case "fixed":
            self = .fixed(width: try c.decode(Int.self, forKey: .width), height: try c.decode(Int.self, forKey: .height))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .mode, in: c, debugDescription: "Bilinmeyen sanal masaüstü modu: \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .off:
            try c.encode("off", forKey: .mode)
        case .auto:
            try c.encode("auto", forKey: .mode)
        case let .fixed(width, height):
            try c.encode("fixed", forKey: .mode)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
        }
    }
}

/// Bir bottle'ın Köprü ayarları.
public struct BottleSettings: Codable, Hashable, Sendable {
    /// WINEMSYNC: Mach semaforlarıyla senkronizasyon; oyunlarda wineserver yükünü azaltır.
    /// Aynı bottle'daki bütün süreçler aynı değerle başlamalı.
    public var msync: Bool
    public var virtualDesktop: VirtualDesktop
    /// Metal HUD (kare hızı göstergesi).
    public var fpsHud: Bool

    public init(msync: Bool = true, virtualDesktop: VirtualDesktop = .off, fpsHud: Bool = false) {
        self.msync = msync
        self.virtualDesktop = virtualDesktop
        self.fpsHud = fpsHud
    }

    public static let `default` = BottleSettings()
}
