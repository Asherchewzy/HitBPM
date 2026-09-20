import Foundation
import Testing
@testable import HitBPM

@MainActor
struct IntervalSettingsStoreTests {
    @Test func settingsRoundTripKeepsZeroDelayAndClearsTarget() {
        let name = "HitBPMTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = IntervalSettingsStore(defaults: defaults)
        #expect(store.load() == .init())
        let settings = IntervalController.Settings(targetBPM: 150, intervalSeconds: 60, resetDelaySeconds: 0)
        store.save(settings)
        #expect(store.load() == settings)
        store.save(.init())
        #expect(store.load().targetBPM == nil)
    }

    @Test func corruptValuesFallBackIndependently() {
        let name = "HitBPMTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = IntervalSettingsStore(defaults: defaults)
        defaults.set(150, forKey: "interval.targetBPM")
        defaults.set(0, forKey: "interval.durationSeconds")
        defaults.set(-1, forKey: "interval.resetDelaySeconds")
        #expect(store.load() == .init(targetBPM: 150))
        defaults.set("150", forKey: "interval.targetBPM")
        defaults.set(true, forKey: "interval.durationSeconds")
        defaults.set(3600, forKey: "interval.resetDelaySeconds")
        #expect(store.load() == .init())
        defaults.set(150.5, forKey: "interval.targetBPM")
        #expect(store.load().targetBPM == nil)
    }
}
