import Foundation

public enum BottleStoreError: Error, Equatable, LocalizedError {
    case emptyName
    case nameTaken(String)
    case notAWineBottle(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Bottle adı boş olamaz."
        case let .nameTaken(name): "“\(name)” adında bir bottle zaten var."
        case let .notAWineBottle(path): "Bu klasör bir Wine bottle'ı değil (içinde system.reg ve drive_c olmalı): \(path)"
        }
    }
}

/// ~/Library/Application Support/Kopru/Bottles altındaki bottle'lar.
public struct BottleStore: Sendable {
    public let paths: KopruPaths

    public init(paths: KopruPaths) { self.paths = paths }

    /// kopru.json'u olan klasörler, görünen ada göre sıralı.
    public func list() throws -> [Bottle] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.bottles.path) else { return [] }
        let folders = try fm.contentsOfDirectory(at: paths.bottles, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return folders
            .compactMap { url in (try? BottleInfo.read(from: url)).map { Bottle(url: url, info: $0) } }
            .sorted { $0.info.name.localizedStandardCompare($1.info.name) == .orderedAscending }
    }

    /// Kırpılmış adı döndürür; boşsa ya da başka bir bottle'da varsa hata.
    public func validateNewName(_ name: String, excluding: Bottle? = nil) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BottleStoreError.emptyName }
        let taken = try list().contains {
            $0.id != excluding?.id && $0.info.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        if taken { throw BottleStoreError.nameTaken(trimmed) }
        return trimmed
    }

    /// `base` boşta ise kendisi, değilse "base 2", "base 3"…: tek tıkla kurulumda bottle adı sorulmaz.
    public func availableName(_ base: String) throws -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(try list().map { $0.info.name.lowercased() })
        guard taken.contains(trimmed.lowercased()) else { return trimmed }
        var number = 2
        while taken.contains("\(trimmed) \(number)".lowercased()) { number += 1 }
        return "\(trimmed) \(number)"
    }

    /// Klasörü ve kopru.json'u oluşturur. Windows ortamını (wineboot) kurmaz.
    public func makeBottle(name: String, settings: BottleSettings, recipeId: String?, now: Date = Date()) throws -> Bottle {
        let name = try validateNewName(name)
        let folder = FolderName.make(from: name, existing: try existingFolderNames())
        let url = paths.bottles.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let bottle = Bottle(url: url, info: BottleInfo(name: name, createdAt: now, recipeId: recipeId, settings: settings))
        try save(bottle)
        return bottle
    }

    public func save(_ bottle: Bottle) throws {
        try bottle.info.write(to: bottle.url)
    }

    /// Yalnızca görünen ad değişir; klasör adı aynı kalır.
    public func rename(_ bottle: Bottle, to newName: String) throws -> Bottle {
        var renamed = bottle
        renamed.info.name = try validateNewName(newName, excluding: bottle)
        try save(renamed)
        return renamed
    }

    /// Varsayılan olarak Çöp Kutusu'na taşır.
    public func delete(_ bottle: Bottle,
                       remover: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        try remover(bottle.url)
    }

    public static func isWineBottle(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.appendingPathComponent("system.reg").path)
            && fm.fileExists(atPath: url.appendingPathComponent("drive_c").path)
    }

    /// Var olan bir Wine bottle'ını Bottles klasörüne taşır ve tanıtır.
    /// Çağıran, taşımadan önce o bottle'ın wineserver'ını kapatmalıdır.
    public func importBottle(from source: URL, name: String, catalog: RecipeCatalog?, now: Date = Date()) throws -> Bottle {
        guard Self.isWineBottle(source) else { throw BottleStoreError.notAWineBottle(source.path) }
        let name = try validateNewName(name)
        let fm = FileManager.default
        try fm.createDirectory(at: paths.bottles, withIntermediateDirectories: true)
        let folder = FolderName.make(from: name, existing: try existingFolderNames())
        let destination = paths.bottles.appendingPathComponent(folder, isDirectory: true)
        try fm.moveItem(at: source, to: destination)

        let recipe = catalog?.detect(in: destination)
        let settings = recipe?.bottle.settings ?? BottleSettings(msync: true, virtualDesktop: .off, fpsHud: false)
        let bottle = Bottle(url: destination, info: BottleInfo(name: name, createdAt: now, recipeId: recipe?.id, settings: settings))
        try save(bottle)
        return bottle
    }

    private func existingFolderNames() throws -> Set<String> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.bottles.path) else { return [] }
        return Set(try fm.contentsOfDirectory(atPath: paths.bottles.path))
    }
}
