import XCTest
@testable import trackthelifts

final class AnalyticsEventTests: XCTestCase {
    func testEventContract() {
        assertEvent(.onboardingSkipped(fromPage: .welcome), name: "Onboarding.skipped", parameters: ["fromPage": "welcome"])
        assertEvent(.onboardingCompleted(skipped: true), name: "Onboarding.completed", parameters: ["skipped": "true"])
        assertEvent(.workoutStarted(source: .blank), name: "Workout.started", parameters: ["source": "blank"])
        assertEvent(
            .workoutCompleted(
                exerciseCount: 3,
                completedSetCount: 9,
                earnedPersonalRecord: true,
                containsSuperset: false
            ),
            name: "Workout.completed",
            parameters: [
                "exerciseCount": "3",
                "completedSetCount": "9",
                "earnedPersonalRecord": "true",
                "containsSuperset": "false",
            ]
        )
        assertEvent(.workoutCancelled(hadLoggedSets: false), name: "Workout.cancelled", parameters: ["hadLoggedSets": "false"])
        assertEvent(.routineSaved(source: .pastWorkout), name: "Routine.saved", parameters: ["source": "pastWorkout"])
        assertEvent(.paywallShown(feature: .supersets), name: "Paywall.shown", parameters: ["feature": "supersets"])
        assertEvent(.purchaseCompleted(packageType: .annual), name: "Purchase.completed", parameters: ["packageType": "annual"])
        assertEvent(.purchaseCancelled(packageType: .monthly), name: "Purchase.cancelled", parameters: ["packageType": "monthly"])
        assertEvent(
            .purchaseFailed(packageType: .other, reason: .sdkError),
            name: "Purchase.failed",
            parameters: ["packageType": "other", "reason": "sdkError"]
        )
        assertEvent(
            .purchaseRestoreCompleted(hasActiveEntitlement: true),
            name: "Purchase.restoreCompleted",
            parameters: ["hasActiveEntitlement": "true"]
        )
        assertEvent(
            .purchaseRestoreFailed(reason: .notConfigured),
            name: "Purchase.restoreFailed",
            parameters: ["reason": "notConfigured"]
        )
    }

    func testStableSourceSerialization() {
        XCTAssertEqual(OnboardingAnalyticsPage.allRawValues, ["welcome", "workouts", "routines", "progress", "personalization", "ready", "profile"])
        XCTAssertEqual(WorkoutAnalyticsSource.blank.rawValue, "blank")
        XCTAssertEqual(WorkoutAnalyticsSource.routine.rawValue, "routine")
        XCTAssertEqual(WorkoutAnalyticsSource.repeatWorkout.rawValue, "repeat")
        XCTAssertEqual(RoutineAnalyticsSource.blank.rawValue, "blank")
        XCTAssertEqual(RoutineAnalyticsSource.pastWorkout.rawValue, "pastWorkout")
        XCTAssertEqual(RoutineAnalyticsSource.duplicate.rawValue, "duplicate")
        XCTAssertEqual(RoutineAnalyticsSource.edit.rawValue, "edit")
        XCTAssertEqual(AnalyticsProFeature.allRawValues, ["unlimitedRoutines", "advancedProgress", "effortTracking", "supersets", "accentThemes"])
    }

    func testRevenueCatPackageTypeFallback() {
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("monthly"), .monthly)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("ANNUAL"), .annual)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("yearly"), .annual)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("lifetime"), .lifetime)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("custom"), .other)
        XCTAssertEqual(AnalyticsFailureReason.fromSDKDescription("notConfigured"), .notConfigured)
        XCTAssertEqual(AnalyticsFailureReason.fromSDKDescription("sdkError"), .sdkError)
        XCTAssertEqual(AnalyticsFailureReason.fromSDKDescription("futureFailure"), .unknown)
    }

    func testEveryEventUsesOnlyApprovedParameterKeys() {
        let events: [AnalyticsEvent] = [
            .onboardingSkipped(fromPage: .welcome),
            .onboardingCompleted(skipped: false),
            .workoutStarted(source: .routine),
            .workoutCompleted(exerciseCount: 1, completedSetCount: 1, earnedPersonalRecord: false, containsSuperset: false),
            .workoutCancelled(hadLoggedSets: true),
            .routineSaved(source: .duplicate),
            .paywallShown(feature: .advancedProgress),
            .purchaseCompleted(packageType: .lifetime),
            .purchaseCancelled(packageType: .other),
            .purchaseFailed(packageType: .monthly, reason: .notConfigured),
            .purchaseRestoreCompleted(hasActiveEntitlement: false),
            .purchaseRestoreFailed(reason: .sdkError),
        ]

        for event in events {
            XCTAssertTrue(
                Set(event.parameters.keys).isSubset(of: AnalyticsEvent.allowedParameterKeys),
                "\(event.name) contains an unapproved analytics parameter"
            )
        }
    }

    private func assertEvent(
        _ event: AnalyticsEvent,
        name: String,
        parameters: [String: String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(event.name, name, file: file, line: line)
        XCTAssertEqual(event.parameters, parameters, file: file, line: line)
    }
}

private extension CaseIterable where Self: RawRepresentable, RawValue == String {
    static var allRawValues: [String] { allCases.map(\.rawValue) }
}
