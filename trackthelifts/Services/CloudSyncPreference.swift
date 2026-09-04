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

    /// Last known Pro entitlement, written by `RevenueCatService` whenever customer info (or
    /// the debug tier override) updates. A change posts `didChangeNotification` so turning on
    /// Pro after launch can snapshot local data the same way the Settings toggle does.
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

    /// Sync is active only when the user opted in AND the last known entitlement was Pro. If
    /// Pro lapses, the next cold launch opens the local-only store — the opt-in is remembered
    /// in case Pro returns.
    var isSyncActive: Bool {
        isEnabled && cachedHasPro
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
