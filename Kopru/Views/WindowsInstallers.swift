import UniformTypeIdentifiers

extension UTType {
    /// Windows kurulum dosyaları (.exe, .msi).
    static let windowsInstallers: [UTType] = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
}
