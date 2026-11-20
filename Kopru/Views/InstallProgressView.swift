import KopruCore
import SwiftUI

/// Adım adım kurulum ilerlemesi; durumu `model.install`'dan okur.
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
            VStack(alignment: .leading, spacing: 10) {
                ForEach(progress.steps, id: \.self) { step in
                    HStack(spacing: 10) {
                        icon(for: step, in: progress).frame(width: 18)
                        Text(step.title)
                        if step == .downloading, progress.current == .downloading, let fraction = progress.fraction {
                            ProgressView(value: fraction).frame(width: 140)
                            Text(fraction, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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

    @ViewBuilder
    private func icon(for step: InstallStep, in progress: InstallProgress) -> some View {
        if progress.failedStep == step {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        } else if progress.done.contains(step) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if progress.current == step {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }
}
