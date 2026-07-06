//
//  RestTimerManager.swift
//  TrackTheLifts
//

import Foundation
import UserNotifications

/// Tracks a rest-between-sets countdown using a wall-clock end date (rather than a
/// running `Timer`) so the remaining time stays correct across app backgrounding.
///
/// Foreground completion (sound + haptic) is handled by `RestTimerBanner`, which only ticks
/// while it's on screen and the app is active. To make sure the user still gets alerted when
/// the app is minimized, this manager also schedules a local notification mirroring `endDate`;
/// iOS delivers that with a sound (and its own haptic) even if the app isn't running.
@Observable
class RestTimerManager {
    static let shared = RestTimerManager()

    private static let completionNotificationIdentifier = "restTimerComplete"

    private(set) var endDate: Date?
    /// Name of the exercise whose completed set started the current rest period, so the UI can
    /// surface the countdown next to that exercise instead of a single fixed location.
    private(set) var activeExerciseName: String?

    @ObservationIgnored
    private let center = UNUserNotificationCenter.current()

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
        scheduleCompletionNotification()
    }

    func addTime(_ seconds: TimeInterval) {
        guard let endDate else { return }
        self.endDate = endDate.addingTimeInterval(seconds)
        scheduleCompletionNotification()
    }

    /// Reduces the remaining rest time, clamped so the countdown never drops into the past (i.e.
    /// remaining time can't go below zero). Callers should also gate the control so it's only
    /// tappable while more than `seconds` remain, keeping the result comfortably positive.
    func subtractTime(_ seconds: TimeInterval) {
        guard let endDate else { return }
        self.endDate = max(endDate.addingTimeInterval(-seconds), Date())
        scheduleCompletionNotification()
    }

    func cancel() {
        endDate = nil
        activeExerciseName = nil
        clearPendingNotification()
    }

    /// Cancels the background notification once the countdown has already been handled
    /// in-app (foreground chime + haptic already fired), so the user doesn't also get a
    /// system banner for a timer they just watched finish.
    func clearPendingNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.completionNotificationIdentifier])
    }

    /// Schedules a local notification for the exact moment the rest timer ends. If the app is
    /// still active when it fires, iOS suppresses the banner/sound by default (no delegate is
    /// registered to opt back in), so this only ever surfaces while the app is backgrounded.
    private func scheduleCompletionNotification() {
        guard let endDate else { return }
        clearPendingNotification()

        Task {
            let allowed = await NotificationService.shared.requestAuthorizationIfNeeded()
            guard allowed else { return }

            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Time to get back to it."
            content.sound = TimerSoundPreference.shared.isEnabled ? .default : nil
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, endDate.timeIntervalSinceNow),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.completionNotificationIdentifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
