//
//  AppTheme.swift
//  TrackTheLifts
//

import SwiftUI

/// Selectable accent color for the whole app. `white` is the default.
enum AppTheme: String, CaseIterable, Identifiable {
    case white
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
        case .white: return .white
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

    /// Readable foreground for content drawn on top of an `color` fill. A white accent needs dark
    /// content; every other accent is dark enough for white content.
    var contrastingForeground: Color {
        self == .white ? .black : .white
    }
}

extension Color {
    /// The user's selected accent color. Reading this inside a view body tracks `ThemePreference`
    /// (an `@Observable`), so every accented view recolors live when the theme changes.
    static var appAccent: Color { ThemePreference.shared.accentColor }

    /// Readable foreground for content placed on top of an `appAccent` fill (black on a white
    /// accent, white otherwise). Keeps buttons/badges legible for every theme.
    static var onAppAccent: Color { ThemePreference.shared.theme.contrastingForeground }

    /// ON-track tint for switches. A pure-white accent hides a switch's white knob, so the white
    /// theme uses a dark track (knob stays visible); every other theme uses the accent itself.
    static var appToggleTint: Color {
        ThemePreference.shared.theme == .white ? Color(white: 0.30) : .appAccent
    }
}
