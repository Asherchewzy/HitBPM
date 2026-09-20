import Foundation

/// Monotonic elapsed time that also advances while the device sleeps.
nonisolated enum WorkoutClock {
    private static let origin = ContinuousClock.now

    static func now() -> TimeInterval {
        let elapsed = origin.duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }
}
