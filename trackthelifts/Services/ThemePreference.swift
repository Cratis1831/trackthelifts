//
//  ThemePreference.swift
//  TrackTheLifts
//

import SwiftUI

/// Persists the user's selected accent theme. Follows the same `@Observable` singleton pattern as
/// `WeightUnitPreference`, so reading `accentColor` in a view body updates it when the theme changes.
@Observable
class ThemePreference {
    static let shared = ThemePreference()

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    var theme: AppTheme {
        didSet {
            userDefaults.set(theme.rawValue, forKey: "appTheme")
        }
    }

    var accentColor: Color { theme.color }

    private init() {
        if let raw = userDefaults.string(forKey: "appTheme"), let saved = AppTheme(rawValue: raw) {
            self.theme = saved
        } else {
            self.theme = .indigo
        }
    }
}
