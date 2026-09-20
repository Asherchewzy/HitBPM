import Foundation
import Testing
@testable import HitBPM

@MainActor
struct HeartRateDeliveryTests {
    @Test func stoppedIntervalStillReceivesLiveHeartRate() {
        let manager = BluetoothHeartRateManager()
        let model = IntervalController(settings: .init(targetBPM: 150))
        manager.onHeartRate = { model.receiveHeartRate($0) }
        manager.acceptMeasurement(Data([0, 150]))
        #expect(model.state == .countdown)
        model.stop()
        manager.acceptMeasurement(Data([0, 165]))
        #expect(manager.currentHeartRate() == 165)
        #expect(model.state == .stopped)
    }

    @Test func longInactivityExpiresIntervalDelayAndCachedHeartRate() {
        var time: TimeInterval = 0
        var completions = 0
        let manager = BluetoothHeartRateManager(now: { time })
        let running = IntervalController(settings: .init(targetBPM: 150), now: { time }, onComplete: { completions += 1 })
        let delaying = IntervalController(settings: .init(targetBPM: 150), now: { time })
        manager.onHeartRate = { running.receiveHeartRate($0) }
        manager.acceptMeasurement(Data([0, 150]))
        delaying.reset()
        time = 3600 // Model returning after device sleep without rendering ticks.
        running.refresh()
        running.refresh()
        delaying.refresh()
        #expect(running.state == .complete)
        #expect(completions == 1)
        #expect(delaying.state == .waiting)
        #expect(manager.currentHeartRate() == nil)
        manager.acceptMeasurement(Data([0, 150]))
        #expect(running.state == .complete)
    }

    @Test func repeatedMeasurementsRearmAfterResetDelay() {
        var time: TimeInterval = 0
        let manager = BluetoothHeartRateManager(now: { time })
        let model = IntervalController(settings: .init(targetBPM: 150), now: { time })
        manager.onHeartRate = { model.receiveHeartRate($0) }
        manager.acceptMeasurement(Data([0, 150]))
        #expect(model.state == .countdown)
        model.reset()
        manager.acceptMeasurement(Data([0, 150]))
        #expect(model.state == .resetDelay)
        time = 10
        manager.acceptMeasurement(Data([0, 150]))
        #expect(model.state == .countdown)
    }

    @Test func staleReadingsCannotTriggerAndMalformedDataDoesNotRefresh() {
        var time: TimeInterval = 0
        let manager = BluetoothHeartRateManager(now: { time })
        var delivered: [Int] = []
        manager.onHeartRate = { delivered.append($0) }
        manager.acceptMeasurement(Data([0, 150]))
        time = 9.999
        #expect(manager.currentHeartRate() == 150)
        manager.acceptMeasurement(Data())
        manager.acceptMeasurement(Data([0, 0]))
        time = 10
        #expect(manager.currentHeartRate() == nil)
        #expect(delivered == [150])
        manager.acceptMeasurement(Data([0, 150]))
        #expect(manager.currentHeartRate() == 150)
        #expect(delivered == [150, 150])
        manager.disconnect()
        #expect(manager.currentHeartRate() == nil)
    }
}
