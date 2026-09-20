import Foundation
import Observation

@MainActor
@Observable
final class IntervalController {
    enum State: Equatable {
        case waiting, countdown, complete, resetDelay, stopped
    }

    nonisolated struct Settings: Equatable {
        var targetBPM: Int? = nil
        var intervalSeconds: Int = 240
        var resetDelaySeconds: Int = 10

        var isValid: Bool {
            (targetBPM.map { $0 > 0 } ?? true)
                && (1...3599).contains(intervalSeconds)
                && (0...3599).contains(resetDelaySeconds)
        }
    }

    private(set) var state: State = .waiting
    private(set) var settings: Settings
    private(set) var remainingSeconds: Int
    private(set) var delayRemainingSeconds = 0
    @ObservationIgnored private var deadline: TimeInterval?
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let onComplete: () -> Void

    init(
        settings: Settings = .init(),
        now: @escaping () -> TimeInterval = { WorkoutClock.now() },
        onComplete: @escaping () -> Void = {}
    ) {
        let validated = settings.isValid ? settings : Settings()
        self.settings = validated
        remainingSeconds = validated.intervalSeconds
        self.now = now
        self.onComplete = onComplete
    }

    var canEditSettings: Bool { state == .waiting || state == .complete || state == .stopped }

    @discardableResult
    func updateSettings(_ settings: Settings) -> Bool {
        guard canEditSettings, settings.isValid else { return false }
        self.settings = settings
        if state != .stopped { state = .waiting }
        remainingSeconds = settings.intervalSeconds
        delayRemainingSeconds = 0
        deadline = nil
        return true
    }

    func receiveHeartRate(_ bpm: Int) {
        refresh()
        guard state == .waiting, let target = settings.targetBPM,
              bpm > 0, bpm >= target else { return }
        state = .countdown
        remainingSeconds = settings.intervalSeconds
        deadline = now() + TimeInterval(settings.intervalSeconds)
    }

    func refresh() {
        guard let deadline else { return }
        let remaining = max(0, Int(ceil(deadline - now())))
        switch state {
        case .countdown:
            remainingSeconds = remaining
            if remaining == 0 {
                self.deadline = nil
                state = .complete
                onComplete()
            }
        case .resetDelay:
            delayRemainingSeconds = remaining
            if remaining == 0 {
                self.deadline = nil
                state = .waiting
            }
        case .waiting, .complete, .stopped:
            break
        }
    }

    func stop() {
        deadline = nil
        state = .stopped
        delayRemainingSeconds = 0
    }

    func reset() {
        guard settings.targetBPM != nil else { return }
        deadline = nil
        remainingSeconds = settings.intervalSeconds
        delayRemainingSeconds = settings.resetDelaySeconds
        if settings.resetDelaySeconds == 0 {
            state = .waiting
        } else {
            state = .resetDelay
            deadline = now() + TimeInterval(settings.resetDelaySeconds)
        }
    }
}
