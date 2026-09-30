//
//  WorkoutShareCardView.swift
//  TrackTheLifts
//

import SwiftUI

/// Visual treatments for the shareable workout card.
enum WorkoutShareCardStyle: String, CaseIterable, Identifiable {
    case midnight
    case bold
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .bold: return "Bold"
        case .light: return "Light"
        }
    }
}

/// A 9:16 story-format workout recap designed for Instagram/TikTok. It is laid out at a fixed
/// 360×640pt canvas and rendered at 3× (1080×1920px), so it never depends on the device's size,
/// Dynamic Type, or the live accent environment.
struct WorkoutShareCardView: View {
    static let canvasSize = CGSize(width: 360, height: 640)
    static let exportScale: CGFloat = 3

    let summary: WorkoutShareSummary
    let style: WorkoutShareCardStyle
    let theme: AppTheme

    private static let maxRecords = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 18)
            titleBlock
            heroVolume
                .padding(.top, 22)
            statRow
                .padding(.top, 18)
            Spacer(minLength: 18)
            if summary.personalRecords.isEmpty {
                exerciseList
            } else {
                recordList
            }
            Spacer(minLength: 18)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 28)
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height, alignment: .topLeading)
        .background { background }
        .clipped()
        .environment(\.colorScheme, style == .light ? .light : .dark)
    }

    // MARK: Palette

    private var accent: Color { theme.color }

    /// Emphasis color that stays visible on the style's background (a white accent disappears on
    /// the light card, and the bold card is already filled with the accent).
    private var highlight: Color {
        switch style {
        case .midnight: return accent
        case .bold: return theme.contrastingForeground
        case .light: return theme == .white ? .black : accent
        }
    }

    private var primaryText: Color {
        switch style {
        case .midnight: return AppDesign.textPrimary
        case .bold: return theme.contrastingForeground
        case .light: return Color(red: 0.07, green: 0.08, blue: 0.10)
        }
    }

    private var secondaryText: Color {
        primaryText.opacity(style == .midnight ? 0.62 : 0.66)
    }

    private var panelFill: Color {
        switch style {
        case .midnight: return Color.white.opacity(0.055)
        case .bold: return theme.contrastingForeground.opacity(0.12)
        case .light: return Color.black.opacity(0.045)
        }
    }

    private var panelStroke: Color {
        switch style {
        case .midnight: return Color.white.opacity(0.09)
        case .bold: return theme.contrastingForeground.opacity(0.18)
        case .light: return Color.black.opacity(0.08)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .midnight:
            ZStack {
                AppDesign.canvas
                RadialGradient(
                    colors: [accent.opacity(0.42), accent.opacity(0)],
                    center: UnitPoint(x: 0.95, y: 0.05),
                    startRadius: 0,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [accent.opacity(0.16), accent.opacity(0)],
                    center: UnitPoint(x: 0, y: 1),
                    startRadius: 0,
                    endRadius: 360
                )
                PrecisionGridBackground(spacing: 18, dotRadius: 0.7)
                    .opacity(0.7)
            }
        case .bold:
            ZStack {
                accent
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.black.opacity(0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
                Text(summary.formattedVolume)
                    .font(.system(size: 210, weight: .black, design: .rounded))
                    .foregroundStyle(theme.contrastingForeground.opacity(0.07))
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .offset(x: 150)
            }
        case .light:
            ZStack {
                Color(red: 0.965, green: 0.955, blue: 0.935)
                RadialGradient(
                    colors: [highlight.opacity(0.14), highlight.opacity(0)],
                    center: UnitPoint(x: 1, y: 0),
                    startRadius: 0,
                    endRadius: 380
                )
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("FORGELYTE LIFT")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.8)
            }
            .foregroundStyle(primaryText)

            Spacer()

            Text(summary.date.formatted(.dateTime.month(.abbreviated).day().year()).uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(secondaryText)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.personalRecords.isEmpty ? "WORKOUT COMPLETE" : "NEW PERSONAL RECORD\(summary.personalRecords.count > 1 ? "S" : "")")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(highlight)

            Text(summary.workoutName)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroVolume: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(summary.formattedVolume)
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(summary.unitLabel.uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(highlight)
            }
            Text("TOTAL VOLUME LIFTED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(secondaryText)
        }
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            stat(summary.formattedDuration, "Time")
            divider
            stat("\(summary.exerciseCount)", summary.exerciseCount == 1 ? "Exercise" : "Exercises")
            divider
            stat("\(summary.completedSetCount)", summary.completedSetCount == 1 ? "Set" : "Sets")
            divider
            stat(WorkoutShareSummary.compactNumber(Double(summary.totalReps)), "Reps")
        }
        .padding(.vertical, 14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(panelStroke, lineWidth: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(panelStroke)
            .frame(width: 1, height: 30)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var recordList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("🏆  PRs THIS SESSION")
            ForEach(summary.personalRecords.prefix(Self.maxRecords)) { record in
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(style == .bold ? accent : Color.black)
                        .frame(width: 34, height: 34)
                        .background(style == .bold ? theme.contrastingForeground : Color(red: 1, green: 0.8, blue: 0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exerciseName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        Text(record.kind.shareLabel.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(secondaryText)
                    }

                    Spacer(minLength: 8)

                    Text(summary.formattedSet(record.performance))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(highlight)
                        .lineLimit(1)
                }
                .padding(10)
                .background(panelFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(panelStroke, lineWidth: 1)
                }
            }
            if summary.personalRecords.count > Self.maxRecords {
                moreLabel(summary.personalRecords.count - Self.maxRecords, noun: "more PR")
            }
        }
    }

    private var exerciseList: some View {
        let limit = 5
        return VStack(alignment: .leading, spacing: 0) {
            sectionLabel("TOP SETS")
                .padding(.bottom, 8)
            ForEach(Array(summary.exercises.prefix(limit).enumerated()), id: \.element.id) { index, line in
                HStack(spacing: 10) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(highlight)
                    Text(line.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(line.setCount)×")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryText)
                    Text(summary.formattedSet(line.topSet))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    if index < min(limit, summary.exercises.count) - 1 {
                        Rectangle().fill(panelStroke).frame(height: 1)
                    }
                }
            }
            if summary.exercises.count > limit {
                moreLabel(summary.exercises.count - limit, noun: "more exercise")
                    .padding(.top, 6)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(secondaryText)
    }

    private func moreLabel(_ count: Int, noun: String) -> some View {
        Text("+ \(count) \(noun)\(count == 1 ? "" : "s")")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(secondaryText)
    }

    private var footer: some View {
        HStack {
            Rectangle()
                .fill(highlight)
                .frame(width: 22, height: 3)
                .clipShape(Capsule())
            Text("Tracked with ForgeLyte Lift")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryText)
            Spacer()
        }
    }
}
