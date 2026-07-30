//
//  RestTimerManager.swift
//  TrackTheLifts
//

import Foundation
import UserNotifications
import ActivityKit

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

    /// Wall-clock time the app most recently became active. Used to tell whether a rest timer
    /// elapsed while the app was backgrounded — in which case its completion notification already
    /// carried the chime — versus during an active session, where the in-app chime should play.
    /// If the timer's `endDate` precedes this, the timer finished while the app was away.
    @ObservationIgnored
    private(set) var lastBecameActiveDate = Date()

    /// Set once the current timer's completion has been alerted in-app, so the foreground driver
    /// (which polls every second) only chimes a single time per timer.
    @ObservationIgnored
    private var completionHandled = false

    @ObservationIgnored
    private let center = UNUserNotificationCenter.current()

    /// The Live Activity mirroring the current countdown in the Dynamic Island / Lock Screen.
    /// Its timer text is system-rendered over start...end, so it only needs an update when the
    /// end date moves, and an end when the countdown finishes or is cancelled.
    @ObservationIgnored
    private var liveActivity: Activity<RestTimerActivityAttributes>?

    /// Start of the running rest period, kept so +/- adjustments preserve the Live Activity's
    /// progress-bar origin instead of restarting it.
    @ObservationIgnored
    private var liveActivityStartDate: Date?

    private init() {}

    func markBecameActive() {
        lastBecameActiveDate = Date()
        // A timer that elapsed (or was abandoned) while the app was away leaves a stale 0:00
        // Live Activity behind — its staleDate has it dimmed by now; remove it on return.
        if !isRunning {
            endLiveActivity()
        }
    }

    /// Called by the app-level foreground driver every second while the scene is active. Returns
    /// `true` exactly once, when the running timer has just elapsed *during this active session*,
    /// so the caller should play the in-app chime. A timer that elapsed while the app was
    /// backgrounded/locked has an `endDate` before `lastBecameActiveDate`; it returns `false` there
    /// (the completion notification was the alert) but still marks it handled so it stays silent.
    func consumeForegroundCompletion() -> Bool {
        guard let endDate, !completionHandled, Date() >= endDate else { return false }
        completionHandled = true
        endLiveActivity()
        return endDate >= lastBecameActiveDate
    }

    var isRunning: Bool {
        guard let endDate else { return false }
        return endDate > .now
    }

    var remainingTime: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(.now))
    }

    func startTimer(duration: TimeInterval? = nil, for exerciseName: String) {
        let duration = duration ?? RestTimerDurationPreference.shared.duration
        endDate = Date().addingTimeInterval(duration)
        activeExerciseName = exerciseName
        completionHandled = false
        scheduleCompletionNotification()
        startLiveActivity(exerciseName: exerciseName)
    }

    func addTime(_ seconds: TimeInterval) {
        guard let endDate else { return }
        self.endDate = endDate.addingTimeInterval(seconds)
        completionHandled = false
        scheduleCompletionNotification()
        updateLiveActivity()
    }

    /// Reduces the remaining rest time, clamped so the countdown never drops into the past (i.e.
    /// remaining time can't go below zero). Callers should also gate the control so it's only
    /// tappable while more than `seconds` remain, keeping the result comfortably positive.
    func subtractTime(_ seconds: TimeInterval) {
        guard let endDate else { return }
        self.endDate = max(endDate.addingTimeInterval(-seconds), Date())
        completionHandled = false
        scheduleCompletionNotification()
        updateLiveActivity()
    }

    func cancel() {
        endDate = nil
        activeExerciseName = nil
        clearPendingNotification()
        endLiveActivity()
    }

    /// Cancels the completion notification once the countdown has been handled in-app (foreground
    /// chime + haptic already fired), so the user doesn't also get a system banner. Removes both
    /// the pending request and any already-delivered copy (iOS may still file a foreground-
    /// suppressed notification in Notification Center) for a timer they just watched finish.
    func clearPendingNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.completionNotificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.completionNotificationIdentifier])
    }

    /// Schedules a local notification for the exact moment the rest timer ends. If the app is
    /// still active when it fires, iOS suppresses the banner/sound by default (no delegate is
    /// registered to opt back in), so this only ever surfaces while the app is backgrounded.
    ///
    /// The request is submitted synchronously via the completion-handler API rather than an
    /// awaited `Task`. This notification matters exactly when the user completes a set and then
    /// immediately backgrounds the app or locks the phone — and that suspends the app, which would
    /// freeze an awaited authorization/add chain before it ever reached `center.add`, so nothing
    /// got scheduled. Enqueuing right here (while still active) makes the request survive.
    private func scheduleCompletionNotification() {
        guard let endDate else { return }
        clearPendingNotification()

        // Ensure permission for next time (first run); harmless when already authorized. We don't
        // gate scheduling on it — an unauthorized add simply won't surface, and the user has
        // already granted notifications in the flows that matter.
        Task { _ = await NotificationService.shared.requestAuthorizationIfNeeded() }

        let content = UNMutableNotificationContent()
        content.title = "Rest Time over!"
        content.body = "Get back at it!"
        // Carry the same bundled chime the app plays in the foreground, so the alert sounds the
        // same whether the timer finishes in-app or while backgrounded. Nil when the user has
        // turned Set Timer Sound off (the notification still shows, just silently).
        content.sound = TimerSoundPreference.shared.isEnabled
            ? UNNotificationSound(named: UNNotificationSoundName(SoundEffects.restTimerSoundName))
            : nil
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
        center.add(request) { error in
            if let error {
                print("Failed to schedule rest timer notification: \(error)")
            }
        }
    }

    // MARK: - Live Activity (Dynamic Island / Lock Screen)

    /// Replaces any existing rest-timer Live Activity with a fresh one for the just-started
    /// countdown. Requires no permission prompt — the user can turn Live Activities off for the
    /// app in iOS Settings, in which case this silently does nothing.
    private func startLiveActivity(exerciseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let endDate else { return }

        // Snapshot the stale activities (including any orphaned by a previous app run) before
        // requesting the replacement, so the async cleanup can't race it away.
        let staleActivities = Activity<RestTimerActivityAttributes>.activities
        Task {
            for activity in staleActivities {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }

        let startDate = Date()
        liveActivityStartDate = startDate
        let content = ActivityContent(
            state: RestTimerActivityAttributes.ContentState(startDate: startDate, endDate: endDate),
            // Once the countdown hits zero the activity has nothing live left to show; marking
            // it stale lets the system dim it until the app returns to clean it up.
            staleDate: endDate,
            // Prefer the short-lived rest timer when another app also has a Live Activity.
            relevanceScore: 1
        )
        do {
            liveActivity = try Activity.request(
                attributes: RestTimerActivityAttributes(
                    exerciseName: exerciseName,
                    accentTheme: ThemePreference.shared.theme.rawValue
                ),
                content: content
            )
        } catch {
            liveActivity = nil
            print("Failed to start rest timer Live Activity: \(error)")
        }
    }

    /// Pushes the moved end date (from +/- adjustments) into the running Live Activity.
    private func updateLiveActivity() {
        guard let liveActivity, let endDate else { return }
        let content = ActivityContent(
            state: RestTimerActivityAttributes.ContentState(
                startDate: liveActivityStartDate ?? Date(),
                endDate: endDate
            ),
            staleDate: endDate,
            relevanceScore: 1
        )
        Task {
            await liveActivity.update(content)
        }
    }

    /// Ends every rest-timer Live Activity (the tracked one plus any orphans from earlier runs).
    private func endLiveActivity() {
        liveActivity = nil
        liveActivityStartDate = nil
        let activities = Activity<RestTimerActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        Task {
            for activity in activities {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }
}
