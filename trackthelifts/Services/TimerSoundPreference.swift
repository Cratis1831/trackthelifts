//
//  TimerSoundPreference.swift
//  TrackTheLifts
//

import Foundation

/// Whether the rest ("set") timer plays a sound when it finishes — both the foreground chime and
/// the sound on the background completion notification. Persisted across launches. Defaults to on
/// so existing users keep the prior always-chimes behavior until they opt out.
@Observable
class TimerSoundPreference {
    static let shared = TimerSoundPreference()

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    var isEnabled: Bool {
        didSet {
            userDefaults.set(isEnabled, forKey: "restTimerSoundEnabled")
        }
    }

    private init() {
        self.isEnabled = userDefaults.object(forKey: "restTimerSoundEnabled") as? Bool ?? true
    }
}
