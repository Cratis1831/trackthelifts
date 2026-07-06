//
//  AppTheme.swift
//  TrackTheLifts
//

import SwiftUI

/// Selectable accent color for the whole app. `orange` is the default (the app's original look).
enum AppTheme: String, CaseIterable, Identifiable {
    case orange
    case red
    case pink
    case purple
    case indigo
    case blue
    case teal
    case green

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        case .indigo: return .indigo
        case .blue: return .blue
        case .teal: return .teal
        case .green: return .green
        }
    }
}

extension Color {
    /// The user's selected accent color. Reading this inside a view body tracks `ThemePreference`
    /// (an `@Observable`), so every accented view recolors live when the theme changes.
    static var appAccent: Color { ThemePreference.shared.accentColor }
}
