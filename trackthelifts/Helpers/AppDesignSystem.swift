//
//  AppDesignSystem.swift
//  TrackTheLifts
//

import SwiftUI

/// The restrained visual language shared by every app surface.
///
/// Accent colors remain user-selectable, but the structural palette stays neutral so content and
/// training data carry the hierarchy rather than large areas of saturated color.
enum AppDesign {
    static let canvas = Color(red: 9 / 255, green: 11 / 255, blue: 14 / 255)
    static let surface = Color(red: 17 / 255, green: 20 / 255, blue: 25 / 255)
    static let elevatedSurface = Color(red: 23 / 255, green: 27 / 255, blue: 33 / 255)
    static let border = Color(red: 40 / 255, green: 46 / 255, blue: 54 / 255)
    static let textPrimary = Color(red: 241 / 255, green: 243 / 255, blue: 245 / 255)
    static let textSecondary = Color(red: 150 / 255, green: 157 / 255, blue: 168 / 255)
    static let textTertiary = Color(red: 112 / 255, green: 120 / 255, blue: 132 / 255)

    static let compactRadius: CGFloat = 7
    static let cardRadius: CGFloat = 9
    static let controlHeight: CGFloat = 46
}

extension Color {
    static let appCanvas = AppDesign.canvas
    static let appSurface = AppDesign.surface
    static let appElevatedSurface = AppDesign.elevatedSurface
    static let appBorder = AppDesign.border
    static let appTextPrimary = AppDesign.textPrimary
    static let appTextSecondary = AppDesign.textSecondary
    static let appTextTertiary = AppDesign.textTertiary
    static let appAction = AppDesign.textPrimary
    static let onAppAction = AppDesign.canvas
}

extension Font {
    static let appScreenTitle = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let appSectionTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let appBody = Font.system(.body, design: .default, weight: .regular)
    static let appCaption = Font.system(.caption, design: .default, weight: .medium)
    static let appUtility = Font.system(.caption, design: .monospaced, weight: .medium)
    static let appMetric = Font.system(.body, design: .monospaced, weight: .semibold)
}

/// A quiet technical grid inspired by a workout log. It is intentionally reserved for top-level
/// dashboard/empty-state backgrounds rather than repeated behind dense forms or lists.
struct PrecisionGridBackground: View {
    var spacing: CGFloat = 22
    var dotRadius: CGFloat = 0.75

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    path.addEllipse(in: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))
                    y += spacing
                }
                x += spacing
            }
            context.fill(path, with: .color(.appBorder.opacity(0.42)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct AppCardModifier: ViewModifier {
    var padding: CGFloat
    var elevated: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(elevated ? Color.appElevatedSurface : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
    }
}

extension View {
    func appCard(padding: CGFloat = 16, elevated: Bool = false) -> some View {
        modifier(AppCardModifier(padding: padding, elevated: elevated))
    }

    func appInputSurface() -> some View {
        self
            .padding(.horizontal, 12)
            .frame(minHeight: AppDesign.controlHeight)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .foregroundStyle(Color.onAppAction)
            .frame(maxWidth: .infinity, minHeight: AppDesign.controlHeight)
            .padding(.horizontal, 14)
            .background(Color.appAction.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .medium))
            .foregroundStyle(Color.appTextPrimary)
            .frame(maxWidth: .infinity, minHeight: AppDesign.controlHeight)
            .padding(.horizontal, 14)
            .background(Color.appElevatedSurface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppStatusBadge: View {
    let text: String
    var color: Color = .appAccent

    var body: some View {
        Text(text.uppercased())
            .font(.appUtility)
            .tracking(0.7)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(color.opacity(0.28), lineWidth: 1)
            }
    }
}
