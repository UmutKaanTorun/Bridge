import Foundation
import Testing
@testable import KopruCore

struct BottleTests {
    @Test func filtersBottlesByRecipe() {
        let steam = Bottle(url: URL(fileURLWithPath: "/tmp/Steam"),
                           info: BottleInfo(name: "Steam", createdAt: .now, recipeId: "steam"))
        let empty = Bottle(url: URL(fileURLWithPath: "/tmp/Bos"), info: BottleInfo(name: "Boş", createdAt: .now))
        #expect([steam, empty].withRecipe("steam").map(\.id) == ["Steam"])
        #expect([steam, empty].withRecipe("winrar").isEmpty)
    }
}
