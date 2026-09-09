//
//  ProductChangeAnnouncementPreference.swift
//  TrackTheLifts
//

import Foundation

/// One-time v2.0 sheet telling existing users that training is free and Pro is nutrition.
@Observable
final class ProductChangeAnnouncementPreference {
    static let shared = ProductChangeAnnouncementPreference()

    @ObservationIgnored
    private let userDefaults: UserDefaults

    @ObservationIgnored
    private let seenKey = "hasSeenV2FreeFitnessAnnouncement"

    var hasSeenAnnouncement: Bool {
        didSet { userDefaults.set(hasSeenAnnouncement, forKey: seenKey) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        hasSeenAnnouncement = userDefaults.bool(forKey: seenKey)
    }

    func shouldPresent(hasCompletedOnboarding: Bool) -> Bool {
        hasCompletedOnboarding && !hasSeenAnnouncement
    }

    func markSeen() {
        hasSeenAnnouncement = true
    }

    func resetSeen() {
        hasSeenAnnouncement = false
    }
}
