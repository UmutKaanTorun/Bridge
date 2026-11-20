import Testing
@testable import KopruCore

struct FolderNameTests {
    @Test(arguments: [
        ("Steam", "Steam"),
        ("Oyunlarım", "Oyunlarim"),
        ("Benim Oyunlarım", "Benim-Oyunlarim"),
        ("Çağrı İş/Ödev", "Cagri-Is-Odev"),
        ("Notepad++", "Notepad++"),
        ("  .gizli  ", "gizli"),
        ("???", "Bottle"),
    ])
    func convertsToASCII(input: String, expected: String) {
        #expect(FolderName.make(from: input, existing: []) == expected)
    }

    @Test func addsNumberOnCollision() {
        #expect(FolderName.make(from: "Steam", existing: ["Steam"]) == "Steam-2")
        #expect(FolderName.make(from: "Steam", existing: ["Steam", "Steam-2"]) == "Steam-3")
    }

    @Test func collisionIsCaseInsensitive() {
        #expect(FolderName.make(from: "oyun!", existing: ["Oyun"]) == "oyun-2")
    }
}
