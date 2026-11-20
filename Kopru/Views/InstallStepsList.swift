import KopruCore
import SwiftUI

/// Kurulum adımları: bitti ✓, sürüyor (dönen), başarısız ✕, bekliyor ○; indirmede yüzde.
struct InstallStepsList: View {
    let progress: InstallProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(progress.steps, id: \.self) { step in
                HStack(spacing: 10) {
                    icon(for: step).frame(width: 18)
                    Text(step.title)
                    if step == .downloading, progress.current == .downloading, let fraction = progress.fraction {
                        ProgressView(value: fraction).frame(maxWidth: 140)
                        Text(fraction, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func icon(for step: InstallStep) -> some View {
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
