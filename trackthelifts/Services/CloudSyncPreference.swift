//
//  CloudSyncPreference.swift
//  TrackTheLifts
//

import Foundation

/// The user's iCloud sync opt-in (a Pro feature, default off) plus a synchronously readable
/// snapshot of the Pro entitlement. The snapshot exists because the SwiftData `ModelContainer`
/// is built at app launch, before RevenueCat's async customer-info load finishes — the last
/// known entitlement decides whether the CloudKit-backed store is used for this launch.
@Observable
class CloudSyncPreference {
    static let shared = CloudSyncPreference()

    /// Must match the container in `trackthelifts.entitlements` (and the App ID's iCloud
    /// capability in the Apple Developer portal).
    static let containerIdentifier = "iCloud.com.ashkansdev.track-the-lifts"

    /// Posted after `isEnabled` changes so the app root can rebuild the model container with
    /// (or without) CloudKit mirroring. The store file on disk is the same either way.
    static let didChangeNotification = Notification.Name("cloudSyncPreferenceDidChange")

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

    /// Last known Pro entitlement, written by `RevenueCatService` whenever customer info (or
    /// the debug tier override) updates.
    var cachedHasPro: Bool {
        didSet { userDefaults.set(cachedHasPro, forKey: cachedProKey) }
    }

    /// Whether the one-time "iCloud Sync is here" announcement card has been dismissed.
    var hasSeenAnnouncement: Bool {
        didSet { userDefaults.set(hasSeenAnnouncement, forKey: announcementSeenKey) }
    }

    /// Sync is active only when the user opted in AND the last known entitlement was Pro. If
    /// Pro lapses, the next container rebuild quietly falls back to the local-only store — the
    /// on-disk data is untouched and the opt-in is remembered in case Pro returns.
    var isSyncActive: Bool {
        isEnabled && cachedHasPro
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isEnabled = userDefaults.bool(forKey: enabledKey)
        self.cachedHasPro = userDefaults.bool(forKey: cachedProKey)
        self.hasSeenAnnouncement = userDefaults.bool(forKey: announcementSeenKey)
    }
}
