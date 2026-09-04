import XCTest
@testable import trackthelifts

final class AppReviewPromptControllerTests: XCTestCase {
    func testFewerThanTwoWorkoutsIsNotEligibleEvenWithPersonalRecord() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 1,
            currentWorkoutEarnedPersonalRecord: true,
            history: .none
        ))
    }

    func testSecondWorkoutIsEligibleOnlyWithPersonalRecord() {
        XCTAssertTrue(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 2,
            currentWorkoutEarnedPersonalRecord: true,
            history: .none
        ))
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 2,
            currentWorkoutEarnedPersonalRecord: false,
            history: .none
        ))
    }

    func testThirdWorkoutIsFallbackWithoutPersonalRecord() {
        XCTAssertTrue(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 3,
            currentWorkoutEarnedPersonalRecord: false,
            history: .none
        ))
    }

    func testImmediateSecondAttemptIsBlocked() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 20,
            currentWorkoutEarnedPersonalRecord: true,
            history: AppReviewRequestHistory(requestCountInLastYear: 1, daysSinceLastRequest: 0)
        ))
    }

    func testSecondPromptAfterThirtyDaysAndEightWorkouts() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 8,
            currentWorkoutEarnedPersonalRecord: false,
            history: AppReviewRequestHistory(requestCountInLastYear: 1, daysSinceLastRequest: 29)
        ))
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 7,
            currentWorkoutEarnedPersonalRecord: false,
            history: AppReviewRequestHistory(requestCountInLastYear: 1, daysSinceLastRequest: 30)
        ))
        XCTAssertTrue(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 8,
            currentWorkoutEarnedPersonalRecord: false,
            history: AppReviewRequestHistory(requestCountInLastYear: 1, daysSinceLastRequest: 30)
        ))
    }

    func testThirdPromptAfterNinetyDaysAndSixteenWorkouts() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 16,
            currentWorkoutEarnedPersonalRecord: true,
            history: AppReviewRequestHistory(requestCountInLastYear: 2, daysSinceLastRequest: 89)
        ))
        XCTAssertTrue(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 16,
            currentWorkoutEarnedPersonalRecord: true,
            history: AppReviewRequestHistory(requestCountInLastYear: 2, daysSinceLastRequest: 90)
        ))
    }

    func testFourthPromptInAYearIsNeverEligible() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 40,
            currentWorkoutEarnedPersonalRecord: true,
            history: AppReviewRequestHistory(requestCountInLastYear: 3, daysSinceLastRequest: 200)
        ))
    }

    func testRegisteringEligibleCompletionPersistsAttemptAndAllowsLaterRetry() {
        withController { controller, defaults in
            let firstAsk = Date(timeIntervalSince1970: 1_000_000)

            XCTAssertTrue(controller.registerCompletion(
                completedWorkoutCount: 3,
                currentWorkoutEarnedPersonalRecord: false,
                now: firstAsk
            ))

            let restoredController = AppReviewPromptController(userDefaults: defaults)
            XCTAssertTrue(restoredController.hasAttemptedAutomaticRequest)
            XCTAssertFalse(restoredController.registerCompletion(
                completedWorkoutCount: 4,
                currentWorkoutEarnedPersonalRecord: true,
                now: firstAsk.addingTimeInterval(86_400)
            ))

            XCTAssertTrue(restoredController.registerCompletion(
                completedWorkoutCount: 8,
                currentWorkoutEarnedPersonalRecord: false,
                now: firstAsk.addingTimeInterval(30 * 86_400)
            ))
        }
    }

    func testLegacyAttemptFlagMigratesWithoutPromptingImmediately() {
        let suiteName = "AppReviewPromptControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "appReview.hasAttemptedAutomaticRequest")
        let controller = AppReviewPromptController(userDefaults: defaults)

        XCTAssertTrue(controller.hasAttemptedAutomaticRequest)
        XCTAssertFalse(controller.registerCompletion(
            completedWorkoutCount: 20,
            currentWorkoutEarnedPersonalRecord: true
        ))
        XCTAssertNil(defaults.object(forKey: "appReview.hasAttemptedAutomaticRequest"))
    }

    func testPersonalRecordWorkoutPersistsAndCanBeClearedOnCompletion() {
        withController { controller, defaults in
            let workoutID = UUID()
            controller.recordPersonalRecord(in: workoutID)

            let restoredController = AppReviewPromptController(userDefaults: defaults)
            XCTAssertEqual(restoredController.pendingPersonalRecordWorkoutID, workoutID)
            XCTAssertTrue(restoredController.hasPendingPersonalRecord(for: workoutID))
            restoredController.clearPendingPersonalRecord(for: workoutID)
            XCTAssertNil(restoredController.pendingPersonalRecordWorkoutID)
        }
    }

    func testPersonalRecordWorkoutCanBeClearedOnCancellation() {
        withController { controller, _ in
            let workoutID = UUID()
            controller.recordPersonalRecord(in: workoutID)
            controller.clearPendingPersonalRecord(for: workoutID)
            XCTAssertNil(controller.pendingPersonalRecordWorkoutID)
        }
    }

    private func withController(
        _ assertions: (AppReviewPromptController, UserDefaults) -> Void
    ) {
        let suiteName = "AppReviewPromptControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        assertions(AppReviewPromptController(userDefaults: defaults), defaults)
    }
}

private extension AppReviewRequestHistory {
    static let none = AppReviewRequestHistory(requestCountInLastYear: 0, daysSinceLastRequest: nil)
}
