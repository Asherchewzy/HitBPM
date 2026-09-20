import Foundation
import CoreFoundation

@MainActor
struct IntervalSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> IntervalController.Settings {
        let target = integer(forKey: "interval.targetBPM")
        let interval = integer(forKey: "interval.durationSeconds")
        let delay = integer(forKey: "interval.resetDelaySeconds")
        return .init(
            targetBPM: target.flatMap { $0 > 0 ? $0 : nil },
            intervalSeconds: interval.flatMap { (1...3599).contains($0) ? $0 : nil } ?? 240,
            resetDelaySeconds: delay.flatMap { (0...3599).contains($0) ? $0 : nil } ?? 10
        )
    }

    func save(_ settings: IntervalController.Settings) {
        guard settings.isValid else { return }
        if let target = settings.targetBPM {
            defaults.set(target, forKey: "interval.targetBPM")
        } else {
            defaults.removeObject(forKey: "interval.targetBPM")
        }
        defaults.set(settings.intervalSeconds, forKey: "interval.durationSeconds")
        defaults.set(settings.resetDelaySeconds, forKey: "interval.resetDelaySeconds")
    }

    private func integer(forKey key: String) -> Int? {
        guard let number = defaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              let value = Int(number.stringValue) else { return nil }
        return value
    }
}
