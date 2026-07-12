//
//  IconTile.swift
//  TrackTheLifts
//

import SwiftUI

/// A compact neutral icon tile with a restrained semantic-color edge.
struct IconTile<Content: View>: View {
    let color: Color
    var size: CGFloat = 30
    var cornerRadius: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.appElevatedSurface)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(0.45), lineWidth: 1)
            }
            .overlay(content.foregroundStyle(Color.appTextPrimary))
    }
}

/// Deterministic per-body-part signal colors. The tile itself stays neutral; these colors only
/// appear as a fine edge so groups remain recognizable without turning the list into a rainbow.
enum BodypartPalette {
    private static let palette: [Color] = [
        Color(red: 0.90, green: 0.30, blue: 0.24), // red
        Color(red: 0.20, green: 0.48, blue: 0.96), // blue
        Color(red: 0.95, green: 0.55, blue: 0.19), // orange
        Color(red: 0.58, green: 0.36, blue: 0.90), // purple
        Color(red: 0.92, green: 0.35, blue: 0.60), // pink
        Color(red: 0.20, green: 0.68, blue: 0.70), // teal
        Color(red: 0.30, green: 0.72, blue: 0.40), // green
        Color(red: 0.36, green: 0.42, blue: 0.90), // indigo
        Color(red: 0.80, green: 0.45, blue: 0.35), // clay
        Color(red: 0.25, green: 0.62, blue: 0.85), // sky
        Color(red: 0.85, green: 0.62, blue: 0.20), // amber
    ]

    private static let byName: [String: Color] = [
        "Chest": palette[0],
        "Back": palette[1],
        "Shoulders": palette[2],
        "Biceps": palette[3],
        "Triceps": palette[4],
        "Forearms": palette[5],
        "Quadriceps": palette[6],
        "Hamstrings": palette[7],
        "Glutes": palette[8],
        "Calves": palette[9],
        "Abs": palette[10],
    ]

    private static let fallback = Color(red: 0.40, green: 0.40, blue: 0.43)

    static func color(for bodypartName: String?) -> Color {
        guard let name = bodypartName, !name.isEmpty else { return fallback }
        if let exact = byName[name] { return exact }
        // Stable (per-launch-independent) hash so custom body parts keep a consistent color.
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}
