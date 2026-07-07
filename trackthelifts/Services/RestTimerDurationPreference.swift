//
//  RestTimerDurationPreference.swift
//  TrackTheLifts
//

import Foundation

/// The default rest ("set") timer duration, in seconds, applied when a completed set kicks off a
/// countdown. Persisted across launches. Defaults to 90 seconds so existing users keep the prior
/// hardcoded 1m30s behavior until they pick a different length in Settings.
@Observable
class RestTimerDurationPreference {
    static let shared = RestTimerDurationPreference()

    /// Rest lengths offered in Settings, in seconds. Common gym rest intervals from a short
    /// 30 seconds up to a full 5 minutes.
    static let options: [TimeInterval] = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    /// The default used before the user has ever chosen one — matches the app's original behavior.
    static let defaultDuration: TimeInterval = 90

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    @ObservationIgnored
    private let storageKey = "restTimerDurationSeconds"

    var duration: TimeInterval {
        didSet {
            userDefaults.set(duration, forKey: storageKey)
        }
    }

    private init() {
        let stored = userDefaults.object(forKey: storageKey) as? TimeInterval
        self.duration = stored ?? Self.defaultDuration
    }

    /// A short human-readable label for a duration, e.g. "1:30" or "45s", suitable for a picker.
    static func label(for duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes == 0 {
            return "\(seconds)s"
        }
        if seconds == 0 {
            return "\(minutes)m"
        }
        return String(format: "%dm %02ds", minutes, seconds)
    }
}
