//
//  ThemePreference.swift
//  TrackTheLifts
//

import SwiftUI

enum ThemeAccessPolicy {
    static func effectiveTheme(selectedTheme: AppTheme, hasProAccess: Bool) -> AppTheme {
        hasProAccess ? selectedTheme : .indigo
    }
}

/// Persists the user's selected accent theme. Follows the same `@Observable` singleton pattern as
/// `WeightUnitPreference`, so reading `accentColor` in a view body updates it when the theme changes.
@Observable
class ThemePreference {
    static let shared = ThemePreference()

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    private(set) var selectedTheme: AppTheme {
        didSet {
            userDefaults.set(selectedTheme.rawValue, forKey: "appTheme")
        }
    }

    private(set) var hasProAccess = false

    /// The paid selection is retained while access is inactive, but indigo is the effective Free
    /// theme. This lets a returning subscriber get their prior theme back without rewriting data.
    var theme: AppTheme {
        ThemeAccessPolicy.effectiveTheme(selectedTheme: selectedTheme, hasProAccess: hasProAccess)
    }

    var accentColor: Color { theme.color }

    func select(_ theme: AppTheme) {
        selectedTheme = theme
    }

    func updateProAccess(_ hasAccess: Bool) {
        hasProAccess = hasAccess
    }

    private init() {
        if let raw = userDefaults.string(forKey: "appTheme"), let saved = AppTheme(rawValue: raw) {
            self.selectedTheme = saved
        } else {
            self.selectedTheme = .indigo
        }
    }
}
