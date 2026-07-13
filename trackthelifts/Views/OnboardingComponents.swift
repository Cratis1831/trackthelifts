//
//  OnboardingComponents.swift
//  TrackTheLifts
//

import SwiftUI

// MARK: - Shared page structure and motion

struct OnboardingPageLayout<Visual: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    let phase: Int
    let visual: Visual

    init(
        eyebrow: String,
        title: String,
        detail: String,
        phase: Int,
        @ViewBuilder visual: () -> Visual
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.phase = phase
        self.visual = visual()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(eyebrow)
                            .font(.appUtility)
                            .tracking(1.5)
                            .foregroundColor(.appAccent)

                        Text(title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(detail)
                            .font(.system(size: 15))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .opacity(phase >= 1 ? 1 : 0)
                    .offset(y: phase >= 1 ? 0 : 12)

                    visual
                        .frame(maxWidth: .infinity)
                        .dynamicTypeSize(.large)
                        .opacity(phase >= 2 ? 1 : 0)
                        .scaleEffect(phase >= 2 ? 1 : 0.975)
                        .offset(y: phase >= 2 ? 0 : 10)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct OnboardingPhaseSequence: ViewModifier {
    let isActive: Bool
    let reduceMotion: Bool
    @Binding var phase: Int
    let finalPhase: Int

    func body(content: Content) -> some View {
        content.task(id: isActive) {
            phase = 0
            guard isActive else { return }

            if reduceMotion {
                phase = finalPhase
                return
            }

            do {
                for step in 1...finalPhase {
                    try await Task.sleep(for: .milliseconds(step == 1 ? 70 : 170))
                    try Task.checkCancellation()
                    withAnimation(step == finalPhase
                        ? .spring(response: 0.48, dampingFraction: 0.78)
                        : .easeOut(duration: 0.34)
                    ) {
                        phase = step
                    }
                }
            } catch {
                // A page swipe cancels the sequence. The next task resets the phase cleanly.
            }
        }
    }
}

private extension View {
    func onboardingPhaseSequence(
        isActive: Bool,
        reduceMotion: Bool,
        phase: Binding<Int>,
        finalPhase: Int = 3
    ) -> some View {
        modifier(OnboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: phase,
            finalPhase: finalPhase
        ))
    }
}

private struct OnboardingSpecimenCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: 3)
                    .padding(.vertical, 14)
            }
    }
}

private struct SpecimenLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(0.9)
            .foregroundColor(.appTextTertiary)
    }
}

// MARK: - Page 1: Welcome

struct WelcomeOnboardingPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Track The Lifts",
            title: "Training, clearly logged.",
            detail: "Capture every set without breaking your rhythm, then see what consistent work builds.",
            phase: phase
        ) {
            WelcomeSpecimen(phase: phase)
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
    }
}

private struct WelcomeSpecimen: View {
    let phase: Int

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.appSurface)
                    .frame(width: 184, height: 184)
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    }

                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .stroke(Color.appAccent.opacity(phase >= 3 ? 0.34 : 0), lineWidth: 2)
                    .frame(width: 154, height: 154)
                    .scaleEffect(phase >= 3 ? 1 : 0.82)

                Image("AppIconDisplay")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 136, height: 136)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .scaleEffect(phase >= 3 ? 1 : 0.88)
            }

            AppStatusBadge(text: "Ready to train", color: .appAccent)
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityHidden(true)
    }
}

// MARK: - Page 2: Workouts

struct WorkoutsOnboardingPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Workouts",
            title: "Stay in the set.",
            detail: "Choose from the exercise library, log weight and reps, see your previous values, and let the rest timer take over when a set is complete.",
            phase: phase
        ) {
            WorkoutSpecimen(phase: phase)
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
    }
}

private struct WorkoutSpecimen: View {
    let phase: Int

    var body: some View {
        OnboardingSpecimenCard {
            VStack(spacing: 13) {
                HStack(spacing: 11) {
                    IconTile(color: Color(red: 0.90, green: 0.30, blue: 0.24), size: 34) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bench Press")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text("Barbell · Working set")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    }

                    Spacer()
                    AppStatusBadge(text: "Set 3")
                }

                Divider().overlay(Color.appBorder)

                HStack {
                    SpecimenLabel(text: "Previous")
                    Spacer()
                    SpecimenLabel(text: "Weight")
                        .frame(width: 58)
                    SpecimenLabel(text: "Reps")
                        .frame(width: 42)
                    SpecimenLabel(text: "Done")
                        .frame(width: 36)
                }

                HStack {
                    Text("80 × 8")
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    specimenValue("82.5", width: 58)
                    specimenValue("8", width: 42)
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(phase >= 3 ? Color.appAccent : Color.clear)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(phase >= 3 ? Color.clear : Color.appBorder, lineWidth: 1)
                        if phase >= 3 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.onAppAccent)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .frame(width: 36)
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .opacity(phase >= 2 ? 1 : 0.3)

                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(Color.appBorder, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: phase >= 3 ? 0.72 : 0.05)
                            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        SpecimenLabel(text: "Rest timer")
                        Text("01:30")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.appTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(10)
                .background(Color.appElevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 8)
            }
        }
        .accessibilityHidden(true)
    }

    private func specimenValue(_ value: String, width: CGFloat) -> some View {
        Text(value)
            .foregroundColor(.appTextPrimary)
            .frame(width: width)
            .frame(height: 30)
            .background(Color.appElevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Page 3: Routines

struct RoutinesOnboardingPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Routines",
            title: "Build once. Train again.",
            detail: "Save workouts as routines and start them in one tap. Free includes up to three routines.",
            phase: phase
        ) {
            RoutineSpecimen(phase: phase)
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
    }
}

private struct RoutineSpecimen: View {
    let phase: Int

    private let routines = [
        ("Push", "6 exercises", "arrow.up.right"),
        ("Pull", "5 exercises", "arrow.down.right"),
        ("Legs", "7 exercises", "figure.strengthtraining.traditional"),
    ]

    private let proFeatures: [ProFeature] = [
        .unlimitedRoutines,
        .supersets,
        .effortTracking,
    ]

    var body: some View {
        OnboardingSpecimenCard {
            VStack(spacing: 10) {
                HStack {
                    SpecimenLabel(text: "My routines")
                    Spacer()
                    Text("3 / 3 FREE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.appAccent)
                }

                ForEach(Array(routines.enumerated()), id: \.offset) { index, routine in
                    HStack(spacing: 10) {
                        IconTile(color: .appAccent, size: 30) {
                            Image(systemName: routine.2)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(routine.0)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                            Text(routine.1)
                                .font(.system(size: 11))
                                .foregroundColor(.appTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.appAccent)
                    }
                    .padding(9)
                    .background(Color.appElevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                    .opacity(phase >= min(3, index + 1) ? 1 : 0.18)
                    .offset(x: phase >= min(3, index + 1) ? 0 : 14)
                }

                Divider().overlay(Color.appBorder)

                VStack(spacing: 7) {
                    ForEach(proFeatures) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: feature.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.appTextSecondary)
                                .frame(width: 16)
                            Text(feature.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                            Spacer()
                            ProBadge()
                        }
                    }
                }
                .opacity(phase >= 3 ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Page 4: Progress

struct ProgressOnboardingPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Progress",
            title: "See the work add up.",
            detail: "Consistency, weekly workouts, and personal-record celebrations are included. Pro adds detailed volume and estimated 1RM trends.",
            phase: phase
        ) {
            ProgressSpecimen(phase: phase)
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
    }
}

private struct ProgressSpecimen: View {
    let phase: Int
    private let weeklyHeights: [CGFloat] = [22, 38, 30, 55, 45, 68, 58]

    var body: some View {
        OnboardingSpecimenCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SpecimenLabel(text: "Consistency")
                    Spacer()
                    Text("8 WEEKS")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.appTextTertiary)
                }

                HStack(spacing: 6) {
                    ForEach(0..<8, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == 2 ? Color.appBorder : Color.appAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                            .opacity(phase >= 2 ? 1 : 0.18)
                    }
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(weeklyHeights.enumerated()), id: \.offset) { index, height in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.appAccent.opacity(index == weeklyHeights.count - 1 ? 1 : 0.48))
                            .frame(maxWidth: .infinity)
                            .frame(height: phase >= 3 ? height : 4)
                    }
                }
                .frame(height: 72, alignment: .bottom)

                HStack(spacing: 10) {
                    IconTile(color: Color(red: 0.85, green: 0.62, blue: 0.20), size: 30) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        SpecimenLabel(text: "Personal record")
                        Text("Bench Press · Weight")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appTextPrimary)
                    }
                    Spacer()
                    Text("+2.5")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.appAccent)
                }
                .padding(10)
                .background(Color.appElevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                .scaleEffect(phase >= 3 ? 1 : 0.96)

                HStack(spacing: 8) {
                    Image(systemName: ProFeature.advancedProgress.systemImage)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                    Text("Volume and estimated 1RM trends")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    ProBadge()
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Page 5: Personalization

struct PersonalizationOnboardingPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Your app",
            title: "Your setup. Your data.",
            detail: "Choose pounds or kilograms, set timers and reminders, edit your history, and export it to CSV whenever you want.",
            phase: phase
        ) {
            PersonalizationSpecimen(phase: phase)
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
    }
}

private struct PersonalizationSpecimen: View {
    let phase: Int

    var body: some View {
        OnboardingSpecimenCard {
            VStack(spacing: 0) {
                settingsRow(
                    symbol: "scalemass.fill",
                    label: "Weight unit",
                    value: "LB  /  KG",
                    color: Color(red: 0.20, green: 0.48, blue: 0.96)
                )
                Divider().overlay(Color.appBorder)
                settingsRow(
                    symbol: "timer",
                    label: "Rest timer",
                    value: "01:30",
                    color: Color(red: 0.95, green: 0.55, blue: 0.19)
                )
                Divider().overlay(Color.appBorder)
                settingsRow(
                    symbol: "square.and.arrow.up",
                    label: "CSV export",
                    value: "READY",
                    color: Color(red: 0.30, green: 0.72, blue: 0.40)
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SpecimenLabel(text: "Accent themes")
                        Spacer()
                        ProBadge()
                    }

                    HStack(spacing: 11) {
                        ForEach([AppTheme.indigo, .purple, .blue, .teal, .green], id: \.self) { theme in
                            ZStack {
                                Circle().fill(theme.color)
                                if theme == .indigo {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .frame(width: 27, height: 27)
                        }
                    }
                }
                .padding(.top, 14)
                .opacity(phase >= 3 ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
    }

    private func settingsRow(symbol: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            IconTile(color: color, size: 30) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appTextPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.appTextSecondary)
        }
        .padding(.vertical, 11)
        .opacity(phase >= 2 ? 1 : 0.24)
    }
}

// MARK: - Page 6: Ready

struct ReadyOnboardingPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Ready",
            title: "Your first set starts here.",
            detail: "Your history, previous values, and progress update as you train. One final detail and you're ready to lift.",
            phase: phase
        ) {
            ReadySpecimen(phase: phase)
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
    }
}

private struct ReadySpecimen: View {
    let phase: Int

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.appAccent.opacity(phase >= 3 ? 0 : 0.38), lineWidth: 2)
                    .frame(width: 96, height: 96)
                    .scaleEffect(phase >= 3 ? 1.75 : 1)
                Circle()
                    .stroke(Color.appBorder, lineWidth: 10)
                    .frame(width: 92, height: 92)
                Circle()
                    .trim(from: 0, to: phase >= 3 ? 1 : 0.08)
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.appAccent)
                    .scaleEffect(phase >= 3 ? 1 : 0.5)
            }

            HStack(spacing: 1) {
                readyMetric("History", "EDITABLE")
                readyMetric("Previous", "READY")
                readyMetric("Progress", "TRACKED")
            }
            .background(Color.appBorder)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
            .opacity(phase >= 3 ? 1 : 0)
        }
        .padding(.vertical, 28)
        .accessibilityHidden(true)
    }

    private func readyMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.appAccent)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(Color.appSurface)
    }
}

// MARK: - Page 7: Profile name

struct ProfileNameOnboardingPage: View {
    @Binding var name: String
    let isActive: Bool
    let onSubmit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    @State private var profile = ProfilePreference.shared
    @FocusState private var isNameFocused: Bool

    var body: some View {
        OnboardingPageLayout(
            eyebrow: "Your profile",
            title: "Before we begin, what can we call you?",
            detail: "This name appears beside your avatar and stays on this device. You can change it anytime.",
            phase: phase
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 15) {
                    avatarPreview

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ProfileNamePolicy.normalized(name).isEmpty ? "Your Name" : ProfileNamePolicy.normalized(name))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)
                        Text("0 Workouts")
                            .font(.system(size: 13))
                            .foregroundColor(.appTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                }
                .scaleEffect(phase >= 3 ? 1 : 0.97)

                TextField(
                    "",
                    text: $name,
                    prompt: Text("Your name").foregroundColor(.appTextTertiary)
                )
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.appTextPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isNameFocused)
                .onSubmit(onSubmit)
                .appInputSurface()

                Text("Required to continue · Editable later from Profile")
                    .font(.appUtility)
                    .foregroundColor(.appTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onboardingPhaseSequence(
            isActive: isActive,
            reduceMotion: reduceMotion,
            phase: $phase
        )
        .task(id: isActive) {
            guard isActive else {
                isNameFocused = false
                return
            }

            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(580))
            }
            guard !Task.isCancelled else { return }
            isNameFocused = true
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        ZStack {
            Circle().fill(Color.appBorder)

            if let image = profile.avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials = ProfileNamePolicy.initials(from: name) {
                Text(initials)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(width: 66, height: 66)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
        .accessibilityHidden(true)
    }
}
