//
//  OnboardingView.swift
//  TrackTheLifts
//

import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome
    case workouts
    case routines
    case progress
    case personalization
    case ready
    case profile

    var id: Int { rawValue }

    var next: OnboardingPage? {
        Self.allCases.first { $0.rawValue == rawValue + 1 }
    }

    var isFinal: Bool { self == .profile }

    static let skipDestination = OnboardingPage.profile

    var analyticsPage: OnboardingAnalyticsPage {
        switch self {
        case .welcome: return .welcome
        case .workouts: return .workouts
        case .routines: return .routines
        case .progress: return .progress
        case .personalization: return .personalization
        case .ready: return .ready
        case .profile: return .profile
        }
    }
}

/// First-launch walkthrough shown once, gated by `hasCompletedOnboarding` in `ContentView`.
/// Reset Onboarding in Settings recreates this view and pre-fills the stored profile name.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = OnboardingPage.welcome
    @State private var nameDraft = ProfilePreference.shared.name
    @State private var didSkip = false

    private var canComplete: Bool {
        !currentPage.isFinal || ProfileNamePolicy.isValid(nameDraft)
    }

    var body: some View {
        ZStack {
            Color.appCanvas.ignoresSafeArea()
            PrecisionGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    WelcomeOnboardingPage(isActive: currentPage == .welcome)
                        .tag(OnboardingPage.welcome)
                    WorkoutsOnboardingPage(isActive: currentPage == .workouts)
                        .tag(OnboardingPage.workouts)
                    RoutinesOnboardingPage(isActive: currentPage == .routines)
                        .tag(OnboardingPage.routines)
                    ProgressOnboardingPage(isActive: currentPage == .progress)
                        .tag(OnboardingPage.progress)
                    PersonalizationOnboardingPage(isActive: currentPage == .personalization)
                        .tag(OnboardingPage.personalization)
                    ReadyOnboardingPage(isActive: currentPage == .ready)
                        .tag(OnboardingPage.ready)
                    ProfileNameOnboardingPage(
                        name: $nameDraft,
                        isActive: currentPage == .profile,
                        onSubmit: completeOnboarding
                    )
                    .tag(OnboardingPage.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                progressRail
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)

                Button(action: advance) {
                    Text(currentPage.isFinal ? "Start Lifting" : "Continue")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .disabled(!canComplete)
                .opacity(canComplete ? 1 : 0.42)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text(String(format: "%02d / %02d", currentPage.rawValue + 1, OnboardingPage.allCases.count))
                .font(.appUtility)
                .tracking(1)
                .foregroundColor(.appTextTertiary)
                .contentTransition(.numericText())

            Spacer()

            Button("Skip") {
                AnalyticsService.track(.onboardingSkipped(fromPage: currentPage.analyticsPage))
                didSkip = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentPage = .skipDestination
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.appTextSecondary)
            .opacity(currentPage.isFinal ? 0 : 1)
            .disabled(currentPage.isFinal)
            .accessibilityHidden(currentPage.isFinal)
        }
        .frame(minHeight: 36)
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var progressRail: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingPage.allCases) { page in
                Capsule()
                    .fill(progressColor(for: page))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
            }
        }
        .animation(.easeOut(duration: 0.25), value: currentPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Page \(currentPage.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }

    private func progressColor(for page: OnboardingPage) -> Color {
        if page == currentPage { return .appAccent }
        if page.rawValue < currentPage.rawValue { return .appTextPrimary.opacity(0.55) }
        return .appBorder
    }

    private func advance() {
        if currentPage.isFinal {
            completeOnboarding()
        } else if let next = currentPage.next {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage = next
            }
        }
    }

    private func completeOnboarding() {
        let normalizedName = ProfileNamePolicy.normalized(nameDraft)
        guard ProfileNamePolicy.isValid(normalizedName) else { return }

        ProfilePreference.shared.name = normalizedName
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        hasCompletedOnboarding = true
        AnalyticsService.track(.onboardingCompleted(skipped: didSkip))
    }
}

#Preview {
    OnboardingView()
}
