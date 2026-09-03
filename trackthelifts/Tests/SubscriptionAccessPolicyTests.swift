import XCTest
@testable import trackthelifts

final class SubscriptionAccessPolicyTests: XCTestCase {
    func testAllProFeaturesRequireProTier() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(SubscriptionAccessPolicy.canAccess(feature, tier: .free))
            XCTAssertTrue(SubscriptionAccessPolicy.canAccess(feature, tier: .pro))
        }
    }

    func testFreeRoutineLimitAllowsFirstThreeRoutines() {
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 0, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 1, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 2, tier: .free))
        XCTAssertFalse(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 3, tier: .free))
        XCTAssertFalse(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 10, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 10, tier: .pro))
    }

    func testFreeCannotCopySupersetSource() {
        XCTAssertTrue(SubscriptionAccessPolicy.canCopyRoutineSource(
            existingCount: 0,
            sourceContainsSupersets: false,
            tier: .free
        ))
        XCTAssertFalse(SubscriptionAccessPolicy.canCopyRoutineSource(
            existingCount: 0,
            sourceContainsSupersets: true,
            tier: .free
        ))
        XCTAssertTrue(SubscriptionAccessPolicy.canCopyRoutineSource(
            existingCount: 20,
            sourceContainsSupersets: true,
            tier: .pro
        ))
    }

    func testDebugOverrideWinsOverEntitlement() {
        XCTAssertEqual(
            SubscriptionAccessPolicy.effectiveTier(entitlementTier: .pro, debugOverride: nil),
            .pro
        )
        XCTAssertEqual(
            SubscriptionAccessPolicy.effectiveTier(entitlementTier: .pro, debugOverride: .free),
            .free
        )
        XCTAssertEqual(
            SubscriptionAccessPolicy.effectiveTier(entitlementTier: .free, debugOverride: .pro),
            .pro
        )
    }

    func testPaidThemeFallsBackAndRestoresWithoutChangingSelection() {
        let selectedTheme = AppTheme.purple

        XCTAssertEqual(
            ThemeAccessPolicy.effectiveTheme(selectedTheme: selectedTheme, hasProAccess: false),
            .indigo
        )
        XCTAssertEqual(
            ThemeAccessPolicy.effectiveTheme(selectedTheme: selectedTheme, hasProAccess: true),
            selectedTheme
        )
    }

    func testEffortPreferenceFallsBackToNoneAndRestoresForPro() {
        let selectedMode = IntensityPreferenceMode.rpe

        XCTAssertEqual(
            IntensityAccessPolicy.effectiveMode(selectedMode: selectedMode, hasProAccess: false),
            .none
        )
        XCTAssertEqual(
            IntensityAccessPolicy.effectiveMode(selectedMode: selectedMode, hasProAccess: true),
            selectedMode
        )
    }

    func testRestTimerFormattingClampsAndPadsSeconds() {
        XCTAssertEqual(RestTimerPresentation.formattedTime(-1), "0:00")
        XCTAssertEqual(RestTimerPresentation.formattedTime(5), "0:05")
        XCTAssertEqual(RestTimerPresentation.formattedTime(90), "1:30")
        XCTAssertEqual(RestTimerPresentation.formattedTime(300), "5:00")
    }

    func testRestTimerProgressUsesConfiguredDurationAndClampsBounds() {
        XCTAssertEqual(RestTimerPresentation.progress(remaining: 45, totalDuration: 90), 0.5)
        XCTAssertEqual(RestTimerPresentation.progress(remaining: -1, totalDuration: 90), 0)
        XCTAssertEqual(RestTimerPresentation.progress(remaining: 120, totalDuration: 90), 1)
        XCTAssertEqual(RestTimerPresentation.progress(remaining: 30, totalDuration: 0), 0)
    }

    func testOnboardingFlowHasEightOrderedPages() {
        XCTAssertEqual(OnboardingPage.allCases.count, 8)
        XCTAssertEqual(OnboardingPage.welcome.next, .workouts)
        XCTAssertEqual(OnboardingPage.workouts.next, .routines)
        XCTAssertEqual(OnboardingPage.routines.next, .progress)
        XCTAssertEqual(OnboardingPage.progress.next, .personalization)
        XCTAssertEqual(OnboardingPage.personalization.next, .ready)
        XCTAssertEqual(OnboardingPage.ready.next, .profile)
        XCTAssertEqual(OnboardingPage.profile.next, .trial)
        XCTAssertNil(OnboardingPage.trial.next)
        XCTAssertTrue(OnboardingPage.trial.isFinal)
        XCTAssertFalse(OnboardingPage.profile.isFinal)
        XCTAssertFalse(OnboardingPage.ready.isFinal)
    }

    func testOnboardingSkipRoutesToProfileSetup() {
        XCTAssertEqual(OnboardingPage.skipDestination, .profile)
    }

    func testProfileNamePolicyNormalizesAndValidatesNames() {
        XCTAssertEqual(ProfileNamePolicy.normalized("  Ashkan Sotoudeh\n"), "Ashkan Sotoudeh")
        XCTAssertTrue(ProfileNamePolicy.isValid(" Ashkan "))
        XCTAssertFalse(ProfileNamePolicy.isValid("  \n\t "))
    }

    func testProfileNamePolicyBuildsAvatarInitials() {
        XCTAssertEqual(ProfileNamePolicy.initials(from: "Ashkan"), "A")
        XCTAssertEqual(ProfileNamePolicy.initials(from: "Ashkan Sotoudeh"), "AS")
        XCTAssertEqual(ProfileNamePolicy.initials(from: "Ashkan Reza Sotoudeh"), "AS")
        XCTAssertNil(ProfileNamePolicy.initials(from: "  "))
    }

    func testPlanKindFallsBackToProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanKind.from(packageTypeDescription: "custom", productIdentifier: "com.app.Monthly"),
            .monthly
        )
        XCTAssertEqual(
            SubscriptionPlanKind.from(packageTypeDescription: "annual", productIdentifier: "ignored"),
            .annual
        )
        XCTAssertEqual(SubscriptionPlanKind.from(productIdentifier: "com.app.lifetime"), .lifetime)
        XCTAssertEqual(SubscriptionPlanKind.annual.displayName, "Yearly")
    }

    func testFreeTrialCopyMatchesAppleDisclosureNeeds() {
        let weeklyTrial = IntroOfferSummary(
            paymentMode: .freeTrial,
            periodCount: 1,
            periodUnit: .week
        )

        XCTAssertEqual(SubscriptionOfferPresentation.durationPhrase(for: weeklyTrial), "1 week")
        XCTAssertEqual(SubscriptionOfferPresentation.hyphenatedDuration(for: weeklyTrial), "1-Week")
        XCTAssertEqual(SubscriptionOfferPresentation.trialCardCaption(for: weeklyTrial), "1 week free")
        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .monthly,
                price: "$1.99",
                intro: weeklyTrial,
                isIntroEligible: true
            ),
            "Start 1-Week Free Trial"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.legalFooter(
                plan: .monthly,
                price: "$1.99",
                intro: weeklyTrial,
                isIntroEligible: true
            ),
            "Free for 1 week, then $1.99/month. Cancel anytime in Settings at least 24 hours before the trial ends."
        )
    }

    func testIneligibleAndLifetimeCopyStayPaid() {
        let weeklyTrial = IntroOfferSummary(
            paymentMode: .freeTrial,
            periodCount: 1,
            periodUnit: .week
        )

        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .monthly,
                price: "$1.99",
                intro: weeklyTrial,
                isIntroEligible: false
            ),
            "Start Pro - $1.99"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .lifetime,
                price: "$24.99",
                intro: nil,
                isIntroEligible: false
            ),
            "Get Lifetime Access - $24.99"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.legalFooter(
                plan: .lifetime,
                price: "$24.99",
                intro: nil,
                isIntroEligible: false
            ),
            "One-time purchase. No subscription, no renewals."
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.settingsUpgradeTitle(isMonthlyTrialEligible: true),
            "Try Pro Free for 1 Week"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.settingsUpgradeTitle(isMonthlyTrialEligible: false),
            "Upgrade to Pro"
        )
    }
}
