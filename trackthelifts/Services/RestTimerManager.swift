//
//  RestTimerManager.swift
//  TrackTheLifts
//

import Foundation

/// Tracks a rest-between-sets countdown using a wall-clock end date (rather than a
/// running `Timer`) so the remaining time stays correct across app backgrounding.
@Observable
class RestTimerManager {
    static let shared = RestTimerManager()

    private(set) var endDate: Date?
    /// Name of the exercise whose completed set started the current rest period, so the UI can
    /// surface the countdown next to that exercise instead of a single fixed location.
    private(set) var activeExerciseName: String?

    private init() {}

    var isRunning: Bool {
        guard let endDate else { return false }
        return endDate > .now
    }

    var remainingTime: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(.now))
    }

    func startTimer(duration: TimeInterval = 90, for exerciseName: String) {
        endDate = Date().addingTimeInterval(duration)
        activeExerciseName = exerciseName
    }

    func addTime(_ seconds: TimeInterval) {
        guard let endDate else { return }
        self.endDate = endDate.addingTimeInterval(seconds)
    }

    func cancel() {
        endDate = nil
        activeExerciseName = nil
    }
}
