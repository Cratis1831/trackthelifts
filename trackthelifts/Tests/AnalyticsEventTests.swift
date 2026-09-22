import XCTest
import RevenueCat
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
        assertEvent(
            .purchaseStarted(packageType: .monthly, isTrial: true),
            name: "Purchase.started",
            parameters: ["packageType": "monthly", "isTrial": "true"]
        )
        assertEvent(
            .purchaseCompleted(packageType: .weekly, isTrial: false),
            name: "Purchase.completed",
            parameters: ["packageType": "weekly", "isTrial": "false"]
        )
        assertEvent(
            .purchaseCompleted(packageType: .annual, isTrial: false),
            name: "Purchase.completed",
            parameters: ["packageType": "annual", "isTrial": "false"]
        )
        assertEvent(
            .purchaseCancelled(packageType: .monthly, isTrial: true),
            name: "Purchase.cancelled",
            parameters: ["packageType": "monthly", "isTrial": "true"]
        )
        assertEvent(
            .purchaseFailed(packageType: .other, isTrial: false, reason: .sdkError),
            name: "Purchase.failed",
            parameters: ["packageType": "other", "isTrial": "false", "reason": "sdkError"]
        )
        assertEvent(
            .purchasePending(packageType: .monthly, isTrial: true),
            name: "Purchase.pending",
            parameters: ["packageType": "monthly", "isTrial": "true"]
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
        XCTAssertEqual(OnboardingAnalyticsPage.allRawValues, ["welcome", "workouts", "routines", "progress", "personalization", "ready", "profile", "trial"])
        XCTAssertEqual(WorkoutAnalyticsSource.blank.rawValue, "blank")
        XCTAssertEqual(WorkoutAnalyticsSource.routine.rawValue, "routine")
        XCTAssertEqual(WorkoutAnalyticsSource.repeatWorkout.rawValue, "repeat")
        XCTAssertEqual(RoutineAnalyticsSource.blank.rawValue, "blank")
        XCTAssertEqual(RoutineAnalyticsSource.pastWorkout.rawValue, "pastWorkout")
        XCTAssertEqual(RoutineAnalyticsSource.duplicate.rawValue, "duplicate")
        XCTAssertEqual(RoutineAnalyticsSource.edit.rawValue, "edit")
        XCTAssertEqual(AnalyticsProFeature.allRawValues, ["icloudSync", "unlimitedRoutines", "advancedProgress", "effortTracking", "supersets", "accentThemes"])
    }

    func testRevenueCatPackageTypeFallback() {
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("weekly"), .weekly)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("monthly"), .monthly)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("ANNUAL"), .annual)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("yearly"), .annual)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("lifetime"), .lifetime)
        XCTAssertEqual(AnalyticsPackageType.fromRevenueCatDescription("custom"), .other)
        XCTAssertEqual(AnalyticsFailureReason.fromSDKDescription("notConfigured"), .notConfigured)
        XCTAssertEqual(AnalyticsFailureReason.fromSDKDescription("sdkError"), .sdkError)
        XCTAssertEqual(AnalyticsFailureReason.fromSDKDescription("futureFailure"), .unknown)
    }

    func testRevenueCatPurchaseErrorDisposition() {
        XCTAssertEqual(
            PurchaseErrorDisposition(
                revenueCatError: NSError(
                    domain: ErrorCode.errorDomain,
                    code: ErrorCode.purchaseCancelledError.rawValue
                )
            ),
            .cancelled
        )
        XCTAssertEqual(
            PurchaseErrorDisposition(
                revenueCatError: NSError(
                    domain: ErrorCode.errorDomain,
                    code: ErrorCode.paymentPendingError.rawValue
                )
            ),
            .pending
        )
        XCTAssertEqual(
            PurchaseErrorDisposition(
                revenueCatError: NSError(
                    domain: ErrorCode.errorDomain,
                    code: ErrorCode.networkError.rawValue
                )
            ),
            .failed
        )
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
            .purchaseStarted(packageType: .monthly, isTrial: true),
            .purchaseCompleted(packageType: .lifetime, isTrial: false),
            .purchaseCancelled(packageType: .other, isTrial: false),
            .purchaseFailed(packageType: .monthly, isTrial: true, reason: .notConfigured),
            .purchasePending(packageType: .monthly, isTrial: true),
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
