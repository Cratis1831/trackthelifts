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

    func testOnboardingFlowHasSevenOrderedPages() {
        XCTAssertEqual(OnboardingPage.allCases.count, 7)
        XCTAssertEqual(OnboardingPage.welcome.next, .workouts)
        XCTAssertEqual(OnboardingPage.workouts.next, .routines)
        XCTAssertEqual(OnboardingPage.routines.next, .progress)
        XCTAssertEqual(OnboardingPage.progress.next, .personalization)
        XCTAssertEqual(OnboardingPage.personalization.next, .ready)
        XCTAssertEqual(OnboardingPage.ready.next, .profile)
        XCTAssertNil(OnboardingPage.profile.next)
        XCTAssertTrue(OnboardingPage.profile.isFinal)
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
}
