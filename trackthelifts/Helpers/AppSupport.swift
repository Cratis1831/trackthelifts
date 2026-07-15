//
//  AppSupport.swift
//  TrackTheLifts
//

import Foundation

enum AppLinks {
    static let manageSubscription = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let website = URL(string: "https://forgelyte-lift.vercel.app/")!
    static let feedback = URL(string: "https://forgelyte-lift.vercel.app/feedback/")!
    static let termsOfService = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://forgelyte-lift.vercel.app/privacy-policy/")!

    /// Opens the review composer directly once the App Store listing is available publicly.
    static let appStoreReview = URL(string: "https://apps.apple.com/app/id6751346666?action=write-review")

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
                "A new Support section makes it easy to manage your subscription, send feedback, share ForgeLyte Lift, review the app, and find legal information."
            ]
        )
    ]
}
