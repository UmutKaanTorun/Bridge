import SwiftUI

struct StartupProblemView: View {
    let problem: StartupProblem

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message).textSelection(.enabled)
        }
    }

    private var title: String {
        switch problem {
        case .engineMissing: "Wine motoru bulunamadı"
        case .rosettaMissing: "Rosetta gerekiyor"
        }
    }

    private var message: String {
        switch problem {
        case let .engineMissing(message), let .rosettaMissing(message): message
        }
    }
}
