import SwiftUI
import KopruCore

@main
struct KopruApp: App {
    var body: some Scene {
        WindowGroup("Köprü") {
            Text("Köprü — bottle klasörü: \(KopruPaths.standard.bottles.path)")
                .padding()
        }
    }
}
