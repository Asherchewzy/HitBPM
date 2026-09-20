import SwiftUI

struct WorkoutTimerView: View {
    let controller: IntervalController
    let onSettingsChanged: (IntervalController.Settings) -> Void
    @State private var editor: Editor?
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 64

    private enum Editor: String, Identifiable {
        case target, interval, delay
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 20) {
            Button {
                editor = .target
            } label: {
                Text(controller.settings.targetBPM.map { "Target \($0) BPM" } ?? "Set target BPM")
                    .font(.title3.bold())
                    .frame(minHeight: 44)
            }
            .disabled(!controller.canEditSettings)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { durationButtons }
                VStack { durationButtons }
            }
            .disabled(!controller.canEditSettings)

            VStack(spacing: 4) {
                Text(status)
                    .font(.headline)
                Text(timeText(displayedSeconds))
                    .font(.system(size: timerSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(controller.state == .resetDelay ? "Reset delay remaining" : "Interval remaining")
                    .accessibilityValue("\(displayedSeconds / 60) minutes, \(displayedSeconds % 60) seconds")
                if controller.state == .resetDelay {
                    Text("Interval \(timeText(controller.remainingSeconds))")
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(controller.state == .complete ? Color.green : Color.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.quaternary, in: .rect(cornerRadius: 16))

            Button("Reset Interval", action: controller.reset)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .disabled(controller.settings.targetBPM == nil)
        }
        .sheet(item: $editor) { selection in
            switch selection {
            case .target:
                TargetHeartRateSheet(target: controller.settings.targetBPM) { target in
                    var settings = controller.settings
                    settings.targetBPM = target
                    save(settings)
                }
            case .interval, .delay:
                DurationPickerSheet(
                    title: selection == .interval ? "Interval" : "Reset delay",
                    seconds: selection == .interval ? controller.settings.intervalSeconds : controller.settings.resetDelaySeconds,
                    allowsZero: selection == .delay
                ) { seconds in
                    var settings = controller.settings
                    if selection == .interval { settings.intervalSeconds = seconds }
                    else { settings.resetDelaySeconds = seconds }
                    save(settings)
                }
            }
        }
        .onChange(of: controller.canEditSettings) {
            if !controller.canEditSettings { editor = nil }
        }
    }

    @ViewBuilder private var durationButtons: some View {
        Button { editor = .interval } label: {
            VStack {
                Text("Interval").font(.subheadline)
                Text(timeText(controller.settings.intervalSeconds)).font(.title3.monospacedDigit())
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        Button { editor = .delay } label: {
            VStack {
                Text("Reset delay").font(.subheadline)
                Text(timeText(controller.settings.resetDelaySeconds)).font(.title3.monospacedDigit())
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var displayedSeconds: Int {
        controller.state == .resetDelay ? controller.delayRemainingSeconds : controller.remainingSeconds
    }

    private var status: String {
        guard controller.settings.targetBPM != nil else { return "Set target BPM to begin" }
        switch controller.state {
        case .waiting: return "Waiting for HR"
        case .countdown: return "Interval in progress"
        case .complete: return "Interval complete"
        case .resetDelay: return "Ready in"
        }
    }

    private func save(_ settings: IntervalController.Settings) {
        if controller.updateSettings(settings) { onSettingsChanged(settings) }
    }

    private func timeText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes < 10 ? "0" : "")\(minutes):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}
