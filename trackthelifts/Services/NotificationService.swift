//
//  NotificationService.swift
//  TrackTheLifts
//

import Foundation
import UserNotifications

/// Schedules a single repeating daily local notification reminding the user to log a workout.
@Observable
class NotificationService {
    static let shared = NotificationService()

    private static let reminderIdentifier = "dailyWorkoutReminder"

    @ObservationIgnored
    private let center = UNUserNotificationCenter.current()
    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    var remindersEnabled: Bool {
        didSet {
            userDefaults.set(remindersEnabled, forKey: "remindersEnabled")
        }
    }

    private(set) var reminderHour: Int {
        didSet {
            userDefaults.set(reminderHour, forKey: "reminderHour")
        }
    }

    private(set) var reminderMinute: Int {
        didSet {
            userDefaults.set(reminderMinute, forKey: "reminderMinute")
        }
    }

    private init() {
        self.remindersEnabled = userDefaults.bool(forKey: "remindersEnabled")
        self.reminderHour = userDefaults.object(forKey: "reminderHour") as? Int ?? 18
        self.reminderMinute = userDefaults.object(forKey: "reminderMinute") as? Int ?? 0
    }

    /// A `Date` (today, at the stored hour/minute) suitable for binding to a `DatePicker`.
    var reminderTime: Date {
        Calendar.current.date(
            from: DateComponents(hour: reminderHour, minute: reminderMinute)
        ) ?? .now
    }

    /// Requests notification authorization if not already determined. Returns whether reminders
    /// are actually allowed to be scheduled (i.e. authorized, not denied).
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("Failed to request notification authorization: \(error)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func setReminderTime(hour: Int, minute: Int) {
        reminderHour = hour
        reminderMinute = minute
        if remindersEnabled {
            scheduleDailyReminder()
        }
    }

    func scheduleDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Time to work out!"
        content.body = "Log a workout today to keep your progress going."
        content.sound = .default

        let dateComponents = DateComponents(hour: reminderHour, minute: reminderMinute)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }
}
