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
    case nutritionDiary
    case nutritionLogging
    case trial
    case profile

    var id: Int { rawValue }

    var next: OnboardingPage? {
        Self.allCases.first { $0.rawValue == rawValue + 1 }
    }

    var isFinal: Bool { self == .profile }

    /// Skip the lifting tour and land on nutrition, then trial, then name.
    static let skipDestination = OnboardingPage.nutritionDiary

    var analyticsPage: OnboardingAnalyticsPage {
        switch self {
        case .welcome: return .welcome
        case .workouts: return .workouts
        case .routines: return .routines
        case .progress: return .progress
        case .personalization: return .personalization
        case .ready: return .ready
        case .nutritionDiary: return .nutritionDiary
        case .nutritionLogging: return .nutritionLogging
        case .trial: return .trial
        case .profile: return .profile
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

    private var isPro: Bool {
        revenueCatService.currentTier == .pro
    }

    private var showsSkip: Bool {
        currentPage != .profile && !(currentPage == .trial && isPro)
    }

    private var skipTitle: String {
        currentPage == .trial ? "Not now" : "Skip"
    }

    private var primaryButtonTitle: String {
        switch currentPage {
        case .trial:
            if isPro { return "Continue" }
            return (revenueCatService.hasEligibleAnnualTrial || revenueCatService.hasEligibleMonthlyTrial)
                ? "Start Free Trial"
                : "See All Plans"
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
                    NutritionDiaryOnboardingPage(isActive: currentPage == .nutritionDiary)
                        .tag(OnboardingPage.nutritionDiary)
                    NutritionLoggingOnboardingPage(isActive: currentPage == .nutritionLogging)
                        .tag(OnboardingPage.nutritionLogging)
                    TrialOnboardingPage(
                        isActive: currentPage == .trial,
                        isPro: isPro,
                        isTrialEligible: revenueCatService.hasEligibleAnnualTrial
                            || revenueCatService.hasEligibleMonthlyTrial,
                        trialDurationText: trialDurationText,
                        monthlyPriceText: revenueCatService.annualPackage?.storeProduct.localizedPriceString
                            ?? revenueCatService.monthlyPackage?.storeProduct.localizedPriceString,
                        introOffer: revenueCatService.annualPackage?.introOfferSummary
                            ?? revenueCatService.monthlyPackage?.introOfferSummary,
                        plan: revenueCatService.hasEligibleAnnualTrial || revenueCatService.annualPackage != nil
                            ? .annual
                            : .monthly,
                        onSeeAllPlans: showAllPlans
                    )
                    .tag(OnboardingPage.trial)
                    ProfileNameOnboardingPage(
                        name: $nameDraft,
                        isActive: currentPage == .profile,
                        onSubmit: advance
                    )
                    .tag(OnboardingPage.profile)
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
            PaywallView(placement: "onboarding")
                .environmentObject(revenueCatService)
        }
        .onAppear {
            trackOnboardingStep()
        }
        .onChange(of: currentPage) {
            trackOnboardingStep()
        }
        .onChange(of: revenueCatService.currentTier) {
            if isPro {
                isPaywallPresented = false
                if currentPage == .trial {
                    goToProfile()
                }
            }
        }
        .appNotice(
            "Purchase Error",
            isPresented: $showingPurchaseError,
            message: purchaseErrorMessage
        )
    }

    private var trialDurationText: String {
        let summary = revenueCatService.annualPackage?.introOfferSummary
            ?? revenueCatService.monthlyPackage?.introOfferSummary
        if let summary {
            return SubscriptionOfferPresentation.durationPhrase(for: summary)
        }
        return "3 days"
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

    private func trackOnboardingStep() {
        let answer: String?
        switch currentPage {
        case .profile:
            answer = ProfileNamePolicy.isValid(nameDraft) ? "named" : nil
        case .trial:
            if isPro {
                answer = "subscribed"
            } else {
                answer = (revenueCatService.hasEligibleAnnualTrial || revenueCatService.hasEligibleMonthlyTrial)
                    ? "trial_eligible"
                    : "see_plans"
            }
        default:
            answer = nil
        }
        ActivationPal.onboardingStep(
            currentPage.rawValue,
            id: currentPage.analyticsPage.rawValue,
            answer: answer
        )
        if currentPage == .trial, !isPro {
            ActivationPal.paywallShown("onboarding")
        }
    }

    private func handleSkip() {
        AnalyticsService.track(.onboardingSkipped(fromPage: currentPage.analyticsPage))
        didSkip = true

        if currentPage == .trial {
            ActivationPal.paywallDismissed()
            goToProfile()
            return
        }

        let destination: OnboardingPage =
            (currentPage == .nutritionDiary || currentPage == .nutritionLogging)
            ? .trial
            : .skipDestination

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = destination
        }
    }

    private func advance() {
        if currentPage == .trial {
            if isPro {
                goToProfile()
                return
            }
            startTrialOrShowPlans()
            return
        }

        if currentPage == .profile {
            finishOnboarding()
            return
        }

        if let next = currentPage.next {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage = next
            }
        }
    }

    private func goToProfile() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = .profile
        }
    }

    private func startTrialOrShowPlans() {
        if revenueCatService.hasEligibleAnnualTrial, let annualPackage = revenueCatService.annualPackage {
            ActivationPal.paywallPlanSelected("yearly")
            Task {
                let success = await revenueCatService.purchasePackage(annualPackage)
                if success {
                    goToProfile()
                } else if let error = revenueCatService.lastError {
                    if case .userCancelled = error { return }
                    purchaseErrorMessage = error.localizedDescription
                    showingPurchaseError = true
                }
            }
            return
        }

        if revenueCatService.hasEligibleMonthlyTrial, let monthlyPackage = revenueCatService.monthlyPackage {
            ActivationPal.paywallPlanSelected("monthly")
            Task {
                let success = await revenueCatService.purchasePackage(monthlyPackage)
                if success {
                    goToProfile()
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
