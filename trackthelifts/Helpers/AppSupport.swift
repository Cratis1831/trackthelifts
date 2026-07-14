//
//  AppSupport.swift
//  TrackTheLifts
//

import Foundation

enum AppLinks {
    static let manageSubscription = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let website = URL(string: "https://www.forgelyte.com/lift")!
    static let feedback = URL(string: "https://forgelyte-lift.userjot.com")!

    /// Set this once ForgeLyte Lift has a numeric App Store ID. Until then, review actions use
    /// Apple's in-app review request.
    static let appStoreReview: URL? = nil

    static let shareMessage = "Build strength and track every lift with ForgeLyte Lift: \(website.absoluteString)"
}

enum AppVersion {
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    static var displayName: String {
        "Version \(marketingVersion) (\(buildNumber))"
    }
}

struct AppRelease: Identifiable {
    let version: String
    let notes: [String]

    var id: String { version }
}

enum ReleaseCatalog {
    static let releases = [
        AppRelease(
            version: "1.0.3",
            notes: [
                "A new Support section makes it easy to manage your subscription, send feedback, share ForgeLyte Lift, and leave a review.",
                "Review requests now appear only after you’ve had time to complete a few workouts and make progress."
            ]
        )
    ]
}
