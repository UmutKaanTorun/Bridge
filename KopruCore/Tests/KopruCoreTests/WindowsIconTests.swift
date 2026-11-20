import Foundation
import Testing
@testable import KopruCore

struct WindowsIconTests {
    private let small = PEBuilder.Icon(id: 1, width: 16, image: Data(repeating: 0xA1, count: 40))
    private let large = PEBuilder.Icon(id: 2, width: 48, image: Data(repeating: 0xB2, count: 90))
    private let other = PEBuilder.Icon(id: 7, width: 32, image: Data(repeating: 0xC3, count: 60))

    @Test(arguments: [true, false])
    func buildsIcoFromFirstGroup(pe32Plus: Bool) throws {
        let exe = PEBuilder.make(groups: [.init(id: 101, icons: [small, large]), .init(id: 102, icons: [other])],
                                 pe32Plus: pe32Plus)
        let ico = try #require(WindowsIcon.icoData(fromExecutableData: exe))
        let entries = try #require(icoEntries(ico))
        #expect(entries.map(\.width) == [16, 48])
        #expect(entries.map(\.image) == [small.image, large.image])
    }

    @Test func indexPicksGroupInOrderAndFallsBackToFirst() throws {
        let exe = PEBuilder.make(groups: [.init(id: 101, icons: [small]), .init(id: 102, icons: [other])])
        #expect(try icoEntries(#require(WindowsIcon.icoData(fromExecutableData: exe, index: 1)))?.map(\.width) == [32])
        #expect(try icoEntries(#require(WindowsIcon.icoData(fromExecutableData: exe, index: 9)))?.map(\.width) == [16])
    }

    /// Windows'ta negatif IconIndex kaynak kimliği demektir.
    @Test func negativeIndexPicksResourceID() throws {
        let exe = PEBuilder.make(groups: [.init(id: 101, icons: [small]), .init(id: 102, icons: [other])])
        #expect(try icoEntries(#require(WindowsIcon.icoData(fromExecutableData: exe, index: -102)))?.map(\.width) == [32])
    }

    @Test func skipsMissingIconsInGroup() throws {
        var exe = PEBuilder.make(groups: [.init(id: 101, icons: [small, large])])
        // İkinci simgenin kimliğini (2) gruptaki girişte 99 yap: grup, olmayan bir simgeyi gösterir.
        let marker = Data(le32(UInt32(large.image.count)) + le16(2))
        let range = try #require(exe.range(of: marker))
        exe.replaceSubrange(range.upperBound - 2 ..< range.upperBound, with: le16(99))
        #expect(try icoEntries(#require(WindowsIcon.icoData(fromExecutableData: exe)))?.map(\.width) == [16])
    }

    @Test func rejectsNonExecutables() {
        #expect(WindowsIcon.icoData(fromExecutableData: Data("merhaba".utf8)) == nil)
        #expect(WindowsIcon.icoData(fromExecutableData: Data(count: 2048)) == nil)
        #expect(WindowsIcon.icoData(fromExecutableData: PEBuilder.make(groups: [])) == nil)
        let truncated = PEBuilder.make(groups: [.init(id: 101, icons: [small])]).prefix(0x410)
        #expect(WindowsIcon.icoData(fromExecutableData: Data(truncated)) == nil)
    }
}
