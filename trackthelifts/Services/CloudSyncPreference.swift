//
//  CloudSyncPreference.swift
//  TrackTheLifts
//

import Foundation

/// The user's iCloud workout-sync opt-in (default off). Workout iCloud sync is free; nutrition
/// history is never stored here. `cachedHasPro` remains for launch-time store choice compatibility
/// with older installs, but it no longer gates sync.
@Observable
class CloudSyncPreference {
    static let shared = CloudSyncPreference()

    /// Must match the container in `trackthelifts.entitlements` (and the App ID's iCloud
    /// capability in the Apple Developer portal).
    static let containerIdentifier = "iCloud.com.ashkansdev.track-the-lifts"

    /// Posted after `isEnabled` or `cachedHasPro` changes so the app root can snapshot local
    /// data and ask for a relaunch. CloudKit cannot be attached mid-process.
    static let didChangeNotification = Notification.Name("cloudSyncPreferenceDidChange")

    static let relaunchMessage = "Force-quit Track The Lifts and reopen to finish turning on iCloud."

    @ObservationIgnored
    private let userDefaults: UserDefaults

    @ObservationIgnored
    private let enabledKey = "iCloudSyncEnabled"

    @ObservationIgnored
    private let cachedProKey = "iCloudSyncCachedHasPro"

    @ObservationIgnored
    private let announcementSeenKey = "hasSeenICloudSyncAnnouncement"

    /// Whether the user has switched iCloud sync on. Off by default so updating the app never
    /// starts uploading anyone's data without an explicit opt-in.
    var isEnabled: Bool {
        didSet {
            userDefaults.set(isEnabled, forKey: enabledKey)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    /// Legacy Pro snapshot. Workout iCloud no longer requires Pro; kept so existing defaults
    /// still round-trip and so a value change can still post `didChangeNotification`.
    var cachedHasPro: Bool {
        didSet {
            userDefaults.set(cachedHasPro, forKey: cachedProKey)
            guard oldValue != cachedHasPro else { return }
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    /// Whether the one-time "iCloud Sync is here" announcement card has been dismissed.
    var hasSeenAnnouncement: Bool {
        didSet { userDefaults.set(hasSeenAnnouncement, forKey: announcementSeenKey) }
    }

    /// Whether the live `ModelContainer` is actually CloudKit-mirrored. In-memory only — it
    /// reflects this process's open store, not the opt-in toggle.
    var isStoreMirrored = false

    /// Last store-open failure, snapshot failure, or relaunch instruction. In-memory only.
    var lastStoreOpenMessage: String?

    /// Sync is active when the user opted in. Nutrition data uses a separate local store and
    /// never opens with this CloudKit configuration.
    var isSyncActive: Bool {
        isEnabled
    }

    /// SwiftData's CloudKit load failure often surfaces as a useless "error 1".
    static func storeOpenFailureMessage(from error: Error) -> String {
        var parts: [String] = []
        func collect(_ nsError: NSError) {
            if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
               !reason.isEmpty,
               parts.last != reason {
                parts.append(reason)
            }
            for value in nsError.userInfo.values {
                if let nested = value as? NSError {
                    collect(nested)
                }
            }
        }
        collect(error as NSError)
        if parts.isEmpty {
            let description = (error as NSError).localizedDescription
            return description.isEmpty ? "Couldn't open iCloud on this install." : description
        }
        return parts.joined(separator: " — ")
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isEnabled = userDefaults.bool(forKey: enabledKey)
        self.cachedHasPro = userDefaults.bool(forKey: cachedProKey)
        self.hasSeenAnnouncement = userDefaults.bool(forKey: announcementSeenKey)
    }
}
