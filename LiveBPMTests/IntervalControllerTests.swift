import Foundation
import Testing
@testable import LiveBPM

@MainActor
struct IntervalControllerTests {
    @Test func thresholdAndUninterruptedDeadline() {
        var time: TimeInterval = 0
        var completions = 0
        let model = IntervalController(settings: .init(targetBPM: 150), now: { time }, onComplete: { completions += 1 })
        model.receiveHeartRate(149)
        #expect(model.state == .waiting)
        model.receiveHeartRate(150)
        #expect(model.state == .countdown)
        time = 120
        model.receiveHeartRate(100)
        #expect(model.remainingSeconds == 120)
        time = 239.999
        model.refresh()
        #expect(model.remainingSeconds == 1)
        #expect(completions == 0)
        time = 245 // No further HR arrives: a disconnected sensor cannot pause timing.
        model.refresh()
        model.refresh()
        model.receiveHeartRate(160)
        #expect(model.state == .complete)
        #expect(model.remainingSeconds == 0)
        #expect(completions == 1)
    }

    @Test func freshReadingAtDelayDeadlineStartsWithoutDisplayTick() {
        var time: TimeInterval = 0
        let model = IntervalController(settings: .init(targetBPM: 150), now: { time })
        model.reset()
        time = 9.999
        model.receiveHeartRate(150)
        #expect(model.state == .resetDelay)
        time = 10
        model.receiveHeartRate(150)
        #expect(model.state == .countdown)
        #expect(model.remainingSeconds == 240)
    }

    @Test func delayExpiryDoesNotReuseReading() {
        var time: TimeInterval = 0
        let model = IntervalController(settings: .init(targetBPM: 150), now: { time })
        model.reset()
        model.receiveHeartRate(160)
        time = 10
        model.refresh()
        #expect(model.state == .waiting)
        model.receiveHeartRate(149)
        #expect(model.state == .waiting)
        model.receiveHeartRate(150)
        #expect(model.state == .countdown)
    }

    @Test(arguments: [0, 1, 2, 3]) func resetFromEveryStatePreservesSettings(start: Int) {
        var time: TimeInterval = 0
        var completions = 0
        let settings = IntervalController.Settings(targetBPM: 150, intervalSeconds: 4, resetDelaySeconds: 3)
        let model = IntervalController(settings: settings, now: { time }, onComplete: { completions += 1 })
        if start == 1 || start == 2 { model.receiveHeartRate(150) }
        if start == 2 { time = 4; model.refresh() }
        if start == 3 { model.reset() }
        let previousCompletions = completions
        time = 5
        model.reset()
        #expect(model.state == .resetDelay)
        #expect(model.remainingSeconds == 4)
        #expect(model.delayRemainingSeconds == 3)
        #expect(model.settings == settings)
        time = 7
        model.refresh()
        #expect(model.delayRemainingSeconds == 1)
        time = 8
        model.refresh()
        #expect(model.state == .waiting)
        #expect(completions == previousCompletions)
    }

    @Test func zeroDelayRequiresNewReading() {
        let model = IntervalController(settings: .init(targetBPM: 150, resetDelaySeconds: 0))
        model.receiveHeartRate(150)
        model.reset()
        #expect(model.state == .waiting)
        model.receiveHeartRate(150)
        #expect(model.state == .countdown)
    }

    @Test func missingTargetAndInvalidSettingsCannotArm() {
        let model = IntervalController()
        model.receiveHeartRate(200)
        model.reset()
        #expect(model.state == .waiting)
        #expect(!model.updateSettings(.init(targetBPM: 0)))
        #expect(!model.updateSettings(.init(targetBPM: 150, intervalSeconds: 0)))
        #expect(!model.updateSettings(.init(targetBPM: 150, resetDelaySeconds: -1)))
        #expect(!model.updateSettings(.init(targetBPM: 150, intervalSeconds: 3600)))
        #expect(!model.updateSettings(.init(targetBPM: 150, resetDelaySeconds: 3600)))
        #expect(model.updateSettings(.init(targetBPM: 150, intervalSeconds: 60)))
        #expect(model.remainingSeconds == 60)
        #expect(model.state == .waiting)
    }

    @Test func settingsLockDuringTimingAndUnlockAtCompletion() {
        var time: TimeInterval = 0
        let model = IntervalController(settings: .init(targetBPM: 150), now: { time })
        model.reset()
        #expect(!model.canEditSettings)
        #expect(!model.updateSettings(.init(targetBPM: 160)))
        time = 10
        model.receiveHeartRate(150)
        #expect(!model.canEditSettings)
        #expect(!model.updateSettings(.init(targetBPM: 160)))
        time = 250
        model.refresh()
        #expect(model.canEditSettings)
        #expect(model.updateSettings(.init(targetBPM: 160)))
        #expect(model.state == .waiting)
    }
}
