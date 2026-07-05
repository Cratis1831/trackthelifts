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

    private init() {}

    var isRunning: Bool {
        guard let endDate else { return false }
        return endDate > .now
    }

    var remainingTime: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(.now))
    }

    func startTimer(duration: TimeInterval = 90) {
        endDate = Date().addingTimeInterval(duration)
    }

    func addTime(_ seconds: TimeInterval) {
        guard let endDate else { return }
        self.endDate = endDate.addingTimeInterval(seconds)
    }

    func cancel() {
        endDate = nil
    }
}
