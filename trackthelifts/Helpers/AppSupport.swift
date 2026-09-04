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
            version: "1.0.8",
            notes: [
                "Try Pro free for 1 week on Monthly: unlimited routines, RPE and RIR, charts, supersets, and every accent theme.",
                "Save completed workouts to Apple Health as Strength Training when you turn that on in Settings.",
                "Start from free Push, Pull, Legs, and Full Body routines. They do not count toward your three custom routines.",
            ]
        ),
        AppRelease(
            version: "1.0.6",
            notes: [
                "iCloud Sync & Backup (Pro): keep every workout backed up to your iCloud and in sync across your devices. Turn it on in Settings.",
                "The rest timer now lives in the Dynamic Island and on your Lock Screen, so you can watch the countdown without reopening the app.",
                "Choose from Weekly, Monthly, Annual, or Lifetime Pro access in the refreshed plan selector."
            ]
        ),
        AppRelease(
            version: "1.0.4",
            notes: [
                "Fixed minor bug for lbs/kg conversion."
            ]
        ),
        AppRelease(
            version: "1.0.3",
            notes: [
                "A new Support section makes it easy to manage your subscription, send feedback, share ForgeLyte Lift, review the app, and find legal information."
            ]
        )
    ]
}
