import Foundation

enum AppReviewEligibilityPolicy {
    static func isEligible(
        completedWorkoutCount: Int,
        currentWorkoutEarnedPersonalRecord: Bool,
        hasAttemptedAutomaticRequest: Bool
    ) -> Bool {
        guard !hasAttemptedAutomaticRequest else { return false }

        if currentWorkoutEarnedPersonalRecord, completedWorkoutCount >= 2 {
            return true
        }

        return completedWorkoutCount >= 3
    }
}

final class AppReviewPromptController {
    static let shared = AppReviewPromptController()

    private enum Key {
        static let hasAttemptedAutomaticRequest = "appReview.hasAttemptedAutomaticRequest"
        static let pendingPersonalRecordWorkoutID = "appReview.pendingPersonalRecordWorkoutID"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasAttemptedAutomaticRequest: Bool {
        userDefaults.bool(forKey: Key.hasAttemptedAutomaticRequest)
    }

    var pendingPersonalRecordWorkoutID: UUID? {
        guard let value = userDefaults.string(forKey: Key.pendingPersonalRecordWorkoutID) else {
            return nil
        }
        return UUID(uuidString: value)
    }

    func recordPersonalRecord(in workoutID: UUID) {
        userDefaults.set(workoutID.uuidString, forKey: Key.pendingPersonalRecordWorkoutID)
    }

    func hasPendingPersonalRecord(for workoutID: UUID) -> Bool {
        pendingPersonalRecordWorkoutID == workoutID
    }

    func clearPendingPersonalRecord(for workoutID: UUID) {
        guard pendingPersonalRecordWorkoutID == workoutID else { return }
        userDefaults.removeObject(forKey: Key.pendingPersonalRecordWorkoutID)
    }

    func registerCompletion(
        completedWorkoutCount: Int,
        currentWorkoutEarnedPersonalRecord: Bool
    ) -> Bool {
        let isEligible = AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: completedWorkoutCount,
            currentWorkoutEarnedPersonalRecord: currentWorkoutEarnedPersonalRecord,
            hasAttemptedAutomaticRequest: hasAttemptedAutomaticRequest
        )

        if isEligible {
            // Record the attempt before asking StoreKit. Apple decides whether a prompt is shown,
            // and the app should not repeatedly interrupt the user when it is suppressed.
            userDefaults.set(true, forKey: Key.hasAttemptedAutomaticRequest)
        }

        return isEligible
    }
}

extension Notification.Name {
    static let appReviewRequestEligible = Notification.Name("appReviewRequestEligible")
}
