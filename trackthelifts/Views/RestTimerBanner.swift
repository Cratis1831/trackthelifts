//
//  RestTimerBanner.swift
//  TrackTheLifts
//

import SwiftUI

/// Pure display calculations shared by the live banner and focused unit tests.
enum RestTimerPresentation {
    static func formattedTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        return String(format: "%d:%02d", clampedSeconds / 60, clampedSeconds % 60)
    }

    static func progress(remaining: TimeInterval, totalDuration: TimeInterval) -> Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(remaining / totalDuration, 0), 1)
    }
}

/// Shows the rest countdown above the exercise whose set started it, keeping the existing
/// wall-clock timing, adjustment, cancellation, notification, sound, and haptic behavior intact.
struct RestTimerBanner: View {
    let exerciseName: String

    private let manager = RestTimerManager.shared
    private let durationPreference = RestTimerDurationPreference.shared
    private let soundPreference = TimerSoundPreference.shared

    var body: some View {
        // The manager's end date changes only when the timer is started or adjusted. A periodic
        // timeline keeps the visible countdown and progress ring synchronized with the wall clock,
        // including immediately removing the card when the timer expires.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if manager.isRunning && manager.activeExerciseName == exerciseName {
                let remainingTime = manager.remainingTime
                let remainingSeconds = max(0, Int(remainingTime.rounded()))

                RestTimerCard(
                    remainingSeconds: remainingSeconds,
                    progress: RestTimerPresentation.progress(
                        remaining: remainingTime,
                        totalDuration: durationPreference.duration
                    ),
                    soundEnabled: soundPreference.isEnabled,
                    canSubtractTime: remainingSeconds > 15,
                    subtractTime: { manager.subtractTime(15) },
                    addTime: { manager.addTime(15) },
                    skip: { manager.cancel() }
                )
            }
        }
    }
}

private struct RestTimerCard: View {
    let remainingSeconds: Int
    let progress: Double
    let soundEnabled: Bool
    let canSubtractTime: Bool
    let subtractTime: () -> Void
    let addTime: () -> Void
    let skip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 12) {
                countdownRing

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest timer")
                        .font(.appUtility)
                        .tracking(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.appTextSecondary)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                    Text(RestTimerPresentation.formattedTime(remainingSeconds))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                        .contentTransition(.numericText(countsDown: true))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest timer")
                .accessibilityValue(accessibilityTime)

                Spacer(minLength: 8)

                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 34, height: 34)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    }
                    .accessibilityLabel(soundEnabled ? "Timer sound on" : "Timer sound off")
            }

            Divider()
                .overlay(Color.appBorder)

            HStack(spacing: 8) {
                timerButton(
                    title: "−15s",
                    accessibilityLabel: "Subtract 15 seconds",
                    isEnabled: canSubtractTime,
                    action: subtractTime
                )
                timerButton(
                    title: "+15s",
                    accessibilityLabel: "Add 15 seconds",
                    action: addTime
                )
                timerButton(
                    title: "Skip",
                    accessibilityLabel: "Skip rest timer",
                    tint: .appAccent,
                    action: skip
                )
            }
        }
        .padding(12)
        .background(Color.appElevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.appBorder, lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.35), value: progress)

            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appAccent)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    private var accessibilityTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        let minuteUnit = minutes == 1 ? "minute" : "minutes"
        let secondUnit = seconds == 1 ? "second" : "seconds"

        if minutes == 0 {
            return "\(seconds) \(secondUnit) remaining"
        }
        if seconds == 0 {
            return "\(minutes) \(minuteUnit) remaining"
        }
        return "\(minutes) \(minuteUnit), \(seconds) \(secondUnit) remaining"
    }

    private func timerButton(
        title: String,
        accessibilityLabel: String,
        tint: Color = .appTextPrimary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Rest timer") {
    ZStack {
        Color.appCanvas.ignoresSafeArea()

        RestTimerCard(
            remainingSeconds: 90,
            progress: 0.72,
            soundEnabled: true,
            canSubtractTime: true,
            subtractTime: {},
            addTime: {},
            skip: {}
        )
        .padding()
    }
}
