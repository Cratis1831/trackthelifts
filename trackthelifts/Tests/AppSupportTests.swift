import XCTest
@testable import trackthelifts

final class AppSupportTests: XCTestCase {
    func testSupportDestinationsAreCentralizedAndCorrect() {
        XCTAssertEqual(AppLinks.manageSubscription.absoluteString, "https://apps.apple.com/account/subscriptions")
        XCTAssertEqual(AppLinks.website.absoluteString, "https://forgelyte-lift.vercel.app/")
        XCTAssertEqual(AppLinks.feedback.absoluteString, "https://forgelyte-lift.vercel.app/feedback/")
        XCTAssertEqual(
            AppLinks.termsOfService.absoluteString,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
        XCTAssertEqual(
            AppLinks.privacyPolicy.absoluteString,
            "https://forgelyte-lift.vercel.app/privacy-policy/"
        )
    }

    func testShareMessageIncludesBrandAndWebsite() {
        XCTAssertTrue(AppLinks.shareMessage.contains("ForgeLyte Lift"))
        XCTAssertTrue(AppLinks.shareMessage.contains(AppLinks.website.absoluteString))
    }

    func testReviewUsesConfiguredAppStoreListing() {
        XCTAssertEqual(
            AppLinks.appStoreReview?.absoluteString,
            "https://apps.apple.com/app/id6751346666?action=write-review"
        )
    }

    func testCurrentVersionAndChangelogMatchReleaseBuildSettings() {
        XCTAssertEqual(AppVersion.marketingVersion, "1.0.8")
        XCTAssertEqual(AppVersion.buildNumber, "1")
        XCTAssertEqual(ReleaseCatalog.releases.first?.version, AppVersion.marketingVersion)
        XCTAssertFalse(ReleaseCatalog.releases.first?.notes.isEmpty ?? true)
        let notes = ReleaseCatalog.releases.first?.notes.joined(separator: " ") ?? ""
        XCTAssertTrue(notes.contains("Try Pro free for 1 week"))
        XCTAssertTrue(notes.contains("Apple Health"))
        XCTAssertTrue(notes.contains("Push, Pull, Legs, and Full Body"))
        XCTAssertFalse(notes.contains("three custom routines"))
        XCTAssertFalse(notes.contains("Weekly Pro"))
        XCTAssertFalse(notes.contains("iCloud Sync stays off"))
        XCTAssertEqual(ReleaseCatalog.current?.version, "1.0.8")
    }

    func testWhatsNewPresentsOncePerVersionUntilReinstall() {
        let defaults = UserDefaults(suiteName: "WhatsNewPreferenceTests")!
        defaults.removePersistentDomain(forName: "WhatsNewPreferenceTests")
        let preference = WhatsNewPreference(userDefaults: defaults)

        XCTAssertFalse(preference.shouldPresent(currentVersion: "1.0.8", hasCompletedOnboarding: false))
        XCTAssertTrue(preference.shouldPresent(currentVersion: "1.0.8", hasCompletedOnboarding: true))

        preference.markCurrentVersionSeen("1.0.8")
        XCTAssertFalse(preference.shouldPresent(currentVersion: "1.0.8", hasCompletedOnboarding: true))

        preference.markCurrentVersionSeen("1.0.6")
        XCTAssertTrue(preference.shouldPresent(currentVersion: "1.0.8", hasCompletedOnboarding: true))
    }
}
