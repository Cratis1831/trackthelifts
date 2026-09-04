import Foundation

struct AppReviewRequestHistory: Equatable {
    var requestCountInLastYear: Int
    var daysSinceLastRequest: Int?
}

enum AppReviewEligibilityPolicy {
    static let maxRequestsPer365Days = 3
    static let yearInDays = 365

    static let firstPromptWorkoutCount = 3
    static let firstPromptWithPRWorkoutCount = 2

    static let secondPromptWorkoutCount = 8
    static let secondPromptMinimumDays = 30

    static let thirdPromptWorkoutCount = 16
    static let thirdPromptMinimumDays = 90

    /// StoreKit may suppress the dialog. There is no API for whether the user left a review,
    /// so later attempts are spaced repeats of a positive moment, capped at Apple's 3 / 365 days.
    static func isEligible(
        completedWorkoutCount: Int,
        currentWorkoutEarnedPersonalRecord: Bool,
        history: AppReviewRequestHistory
    ) -> Bool {
        guard history.requestCountInLastYear < maxRequestsPer365Days else { return false }

        switch history.requestCountInLastYear {
        case 0:
            if currentWorkoutEarnedPersonalRecord, completedWorkoutCount >= firstPromptWithPRWorkoutCount {
                return true
            }
            return completedWorkoutCount >= firstPromptWorkoutCount

        case 1:
            guard let daysSinceLastRequest = history.daysSinceLastRequest,
                  daysSinceLastRequest >= secondPromptMinimumDays else { return false }
            return completedWorkoutCount >= secondPromptWorkoutCount

        default:
            guard let daysSinceLastRequest = history.daysSinceLastRequest,
                  daysSinceLastRequest >= thirdPromptMinimumDays else { return false }
            return completedWorkoutCount >= thirdPromptWorkoutCount
        }
    }
}

final class AppReviewPromptController {
    static let shared = AppReviewPromptController()

    private enum Key {
        static let hasAttemptedAutomaticRequest = "appReview.hasAttemptedAutomaticRequest"
        static let automaticRequestTimestamps = "appReview.automaticRequestTimestamps"
        static let pendingPersonalRecordWorkoutID = "appReview.pendingPersonalRecordWorkoutID"
    }

    private static let secondsPerDay: TimeInterval = 86_400

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        migrateLegacyAttemptFlagIfNeeded()
    }

    var hasAttemptedAutomaticRequest: Bool {
        !storedRequestDates.isEmpty
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
        currentWorkoutEarnedPersonalRecord: Bool,
        now: Date = .now
    ) -> Bool {
        let history = requestHistory(at: now)
        let isEligible = AppReviewEligibilityPolicy.isEligible(
            completedWorkoutCount: completedWorkoutCount,
            currentWorkoutEarnedPersonalRecord: currentWorkoutEarnedPersonalRecord,
            history: history
        )

        if isEligible {
            // Record the attempt before asking StoreKit. Apple decides whether a prompt is shown
            // and limits the system dialog to three times in 365 days.
            appendRequest(at: now)
        }

        return isEligible
    }

    func requestHistory(at now: Date = .now) -> AppReviewRequestHistory {
        let windowStart = now.addingTimeInterval(-TimeInterval(AppReviewEligibilityPolicy.yearInDays) * Self.secondsPerDay)
        let recent = storedRequestDates.filter { $0 >= windowStart }
        let daysSinceLastRequest = storedRequestDates.max().map { last in
            max(0, Int(now.timeIntervalSince(last) / Self.secondsPerDay))
        }
        return AppReviewRequestHistory(
            requestCountInLastYear: recent.count,
            daysSinceLastRequest: daysSinceLastRequest
        )
    }

    private var storedRequestDates: [Date] {
        let timestamps = userDefaults.array(forKey: Key.automaticRequestTimestamps) as? [Double] ?? []
        return timestamps.map { Date(timeIntervalSince1970: $0) }
    }

    private func appendRequest(at date: Date) {
        var timestamps = userDefaults.array(forKey: Key.automaticRequestTimestamps) as? [Double] ?? []
        timestamps.append(date.timeIntervalSince1970)
        userDefaults.set(timestamps, forKey: Key.automaticRequestTimestamps)
    }

    private func migrateLegacyAttemptFlagIfNeeded() {
        guard userDefaults.bool(forKey: Key.hasAttemptedAutomaticRequest) else { return }
        if storedRequestDates.isEmpty {
            appendRequest(at: .now)
        }
        userDefaults.removeObject(forKey: Key.hasAttemptedAutomaticRequest)
    }
}

extension Notification.Name {
    static let appReviewRequestEligible = Notification.Name("appReviewRequestEligible")
}
