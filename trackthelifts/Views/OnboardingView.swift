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
    case trial

    var id: Int { rawValue }

    var next: OnboardingPage? {
        Self.allCases.first { $0.rawValue == rawValue + 1 }
    }

    var isFinal: Bool { self == .trial }

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
        case .trial: return .trial
        }
    }
}

/// First-launch walkthrough shown once, gated by `hasCompletedOnboarding` in `ContentView`.
/// Reset Onboarding in Settings recreates this view and pre-fills the stored profile name.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var revenueCatService: RevenueCatService
    @State private var currentPage = OnboardingPage.welcome
    @State private var nameDraft = ProfilePreference.shared.name
    @State private var didSkip = false
    @State private var isPaywallPresented = false
    @State private var showingPurchaseError = false
    @State private var purchaseErrorMessage = ""

    private var canAdvance: Bool {
        currentPage != .profile || ProfileNamePolicy.isValid(nameDraft)
    }

    private var showsSkip: Bool {
        currentPage != .profile
    }

    private var skipTitle: String {
        currentPage == .trial ? "Not now" : "Skip"
    }

    private var primaryButtonTitle: String {
        switch currentPage {
        case .trial:
            return revenueCatService.hasEligibleMonthlyTrial ? "Start Free Trial" : "See All Plans"
        default:
            return "Continue"
        }
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
                        onSubmit: advance
                    )
                    .tag(OnboardingPage.profile)
                    TrialOnboardingPage(
                        isActive: currentPage == .trial,
                        isTrialEligible: revenueCatService.hasEligibleMonthlyTrial,
                        trialDurationText: trialDurationText,
                        monthlyPriceText: revenueCatService.monthlyPackage?.storeProduct.localizedPriceString,
                        introOffer: revenueCatService.monthlyPackage?.introOfferSummary,
                        onSeeAllPlans: showAllPlans
                    )
                    .tag(OnboardingPage.trial)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                progressRail
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)

                Button(action: advance) {
                    if revenueCatService.isLoading && currentPage == .trial {
                        ProgressView()
                            .tint(Color.onAppAction)
                    } else {
                        Text(primaryButtonTitle)
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .disabled(!canAdvance || (revenueCatService.isLoading && currentPage == .trial))
                .opacity(canAdvance ? 1 : 0.42)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView()
                .environmentObject(revenueCatService)
        }
        .onChange(of: currentPage) {
            if currentPage == .trial, !ProfileNamePolicy.isValid(nameDraft) {
                currentPage = .profile
            }
        }
        .onChange(of: revenueCatService.currentTier) {
            if revenueCatService.currentTier == .pro {
                finishOnboarding()
            }
        }
        .alert("Purchase Error", isPresented: $showingPurchaseError) {
            Button("OK") { }
        } message: {
            Text(purchaseErrorMessage)
        }
    }

    private var trialDurationText: String {
        if let summary = revenueCatService.monthlyPackage?.introOfferSummary {
            return SubscriptionOfferPresentation.durationPhrase(for: summary)
        }
        return "1 week"
    }

    private var topBar: some View {
        HStack {
            Text(String(format: "%02d / %02d", currentPage.rawValue + 1, OnboardingPage.allCases.count))
                .font(.appUtility)
                .tracking(1)
                .foregroundColor(.appTextTertiary)
                .contentTransition(.numericText())

            Spacer()

            Button(skipTitle) {
                handleSkip()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.appTextSecondary)
            .opacity(showsSkip ? 1 : 0)
            .disabled(!showsSkip)
            .accessibilityHidden(!showsSkip)
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

    private func handleSkip() {
        if currentPage == .trial {
            finishOnboarding()
            return
        }

        AnalyticsService.track(.onboardingSkipped(fromPage: currentPage.analyticsPage))
        didSkip = true
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = .skipDestination
        }
    }

    private func advance() {
        if currentPage == .trial {
            startTrialOrShowPlans()
            return
        }

        if currentPage == .profile {
            guard persistNameIfValid() else { return }
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if revenueCatService.currentTier == .pro {
                finishOnboarding()
                return
            }
        }

        if let next = currentPage.next {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage = next
            }
        }
    }

    private func startTrialOrShowPlans() {
        if revenueCatService.hasEligibleMonthlyTrial, let monthlyPackage = revenueCatService.monthlyPackage {
            Task {
                let success = await revenueCatService.purchasePackage(monthlyPackage)
                if success {
                    finishOnboarding()
                } else if let error = revenueCatService.lastError {
                    if case .userCancelled = error { return }
                    purchaseErrorMessage = error.localizedDescription
                    showingPurchaseError = true
                }
            }
            return
        }

        showAllPlans()
    }

    private func showAllPlans() {
        isPaywallPresented = true
    }

    private func persistNameIfValid() -> Bool {
        let normalizedName = ProfileNamePolicy.normalized(nameDraft)
        guard ProfileNamePolicy.isValid(normalizedName) else { return false }
        ProfilePreference.shared.name = normalizedName
        return true
    }

    private func finishOnboarding() {
        guard persistNameIfValid() else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        hasCompletedOnboarding = true
        AnalyticsService.track(.onboardingCompleted(skipped: didSkip))
    }
}

#Preview {
    OnboardingView()
        .environmentObject(RevenueCatService.shared)
}
