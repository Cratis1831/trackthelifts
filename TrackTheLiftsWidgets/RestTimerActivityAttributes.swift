//
//  RestTimerActivityAttributes.swift
//  TrackTheLifts
//

import Foundation
import ActivityKit

/// Shared between the app target (which starts/updates/ends the rest-timer Live Activity from
/// `RestTimerManager`) and the widget extension (which renders it on the Lock Screen and in the
/// Dynamic Island). Compiled into both targets — the struct must stay identical on each side
/// for ActivityKit to route updates.
struct RestTimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the current rest period started. With `endDate` it forms the interval that the
        /// system-rendered countdown text and progress ring tick through on their own — the app
        /// never needs to push per-second updates.
        var startDate: Date
        /// When the rest period ends.
        var endDate: Date
    }

    /// Exercise whose completed set kicked off this rest period.
    var exerciseName: String

    /// App accent selected when the timer starts. The widget extension runs in a separate process,
    /// so it can't observe the app's standard UserDefaults-backed ThemePreference directly.
    var accentTheme: String
}
