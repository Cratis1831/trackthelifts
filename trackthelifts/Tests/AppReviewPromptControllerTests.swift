import XCTest
@testable import trackthelifts

final class AppReviewPromptControllerTests: XCTestCase {
    func testFewerThanTwoWorkoutsIsNotEligibleEvenWithPersonalRecord() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 1,
            currentWorkoutEarnedPersonalRecord: true,
            hasAttemptedAutomaticRequest: false
        ))
    }

    func testSecondWorkoutIsEligibleOnlyWithPersonalRecord() {
        XCTAssertTrue(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 2,
            currentWorkoutEarnedPersonalRecord: true,
            hasAttemptedAutomaticRequest: false
        ))
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 2,
            currentWorkoutEarnedPersonalRecord: false,
            hasAttemptedAutomaticRequest: false
        ))
    }

    func testThirdWorkoutIsFallbackWithoutPersonalRecord() {
        XCTAssertTrue(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 3,
            currentWorkoutEarnedPersonalRecord: false,
            hasAttemptedAutomaticRequest: false
        ))
    }

    func testPriorAttemptPreventsAnotherAutomaticRequest() {
        XCTAssertFalse(AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: 20,
            currentWorkoutEarnedPersonalRecord: true,
            hasAttemptedAutomaticRequest: true
        ))
    }

    func testRegisteringEligibleCompletionPersistsAttempt() {
        withController { controller, defaults in
            XCTAssertTrue(controller.registerCompletion(
                completedWorkoutCount: 3,
                currentWorkoutEarnedPersonalRecord: false
            ))

            let restoredController = AppReviewPromptController(userDefaults: defaults)
            XCTAssertTrue(restoredController.hasAttemptedAutomaticRequest)
            XCTAssertFalse(restoredController.registerCompletion(
                completedWorkoutCount: 4,
                currentWorkoutEarnedPersonalRecord: true
            ))
        }
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
