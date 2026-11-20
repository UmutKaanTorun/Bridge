import KopruCore
import SwiftUI

/// Sheet olarak adım adım kurulum ilerlemesi; durumu `model.install`'dan okur.
struct InstallProgressView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let progress = model.install {
            content(progress)
                .padding(20)
                .frame(width: 460, height: 320)
                .interactiveDismissDisabled(progress.isActive)
        }
    }

    private func content(_ progress: InstallProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(progress.title).font(.title2.bold())
            InstallStepsList(progress: progress)
            if let message = progress.errorMessage {
                Text(message).foregroundStyle(.red).textSelection(.enabled)
            }
            Spacer()
            HStack {
                if progress.failedStep != nil {
                    if let bottle = progress.bottle {
                        Button("Günlüğü Göster") { model.openLog(model.logURL(for: bottle)) }
                    }
                    Spacer()
                    if progress.createsBottle, progress.bottle != nil {
                        Button("Yarım Bottle'ı Sil", role: .destructive) { model.deleteFailedInstallBottle() }
                    }
                    Button(progress.createsBottle && progress.bottle != nil ? "Tut ve Kapat" : "Kapat") { model.install = nil }
                        .keyboardShortcut(.defaultAction)
                } else if progress.finished {
                    Spacer()
                    Button("Bitti") { model.install = nil }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Spacer()
                    Text("Kurulum sürüyor…").foregroundStyle(.secondary)
                }
            }
        }
    }
}
