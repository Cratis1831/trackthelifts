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
}
