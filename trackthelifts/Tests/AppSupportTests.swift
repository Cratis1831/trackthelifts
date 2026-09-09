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
        XCTAssertEqual(AppVersion.marketingVersion, "2.0.0")
        XCTAssertEqual(AppVersion.buildNumber, "1")
        XCTAssertEqual(ReleaseCatalog.releases.first?.version, AppVersion.marketingVersion)
        XCTAssertFalse(ReleaseCatalog.releases.first?.notes.isEmpty ?? true)
        let notes = ReleaseCatalog.releases.first?.notes.joined(separator: " ") ?? ""
        XCTAssertTrue(notes.contains("Training is free"))
        XCTAssertTrue(notes.contains("Nutrition"))
        XCTAssertTrue(notes.contains("Settings"))
        XCTAssertEqual(ReleaseCatalog.current?.version, "2.0.0")
        XCTAssertEqual(AppLinks.usdaFoodDataCentral.absoluteString, "https://fdc.nal.usda.gov/")
        XCTAssertEqual(AppLinks.openFoodFacts.absoluteString, "https://world.openfoodfacts.org/")
    }

    func testWhatsNewPresentsOncePerVersionUntilReinstall() {
        let defaults = UserDefaults(suiteName: "WhatsNewPreferenceTests")!
        defaults.removePersistentDomain(forName: "WhatsNewPreferenceTests")
        let preference = WhatsNewPreference(userDefaults: defaults)

        XCTAssertFalse(preference.shouldPresent(currentVersion: "2.0.0", hasCompletedOnboarding: false))
        XCTAssertTrue(preference.shouldPresent(currentVersion: "2.0.0", hasCompletedOnboarding: true))

        preference.markCurrentVersionSeen("2.0.0")
        XCTAssertFalse(preference.shouldPresent(currentVersion: "2.0.0", hasCompletedOnboarding: true))

        preference.markCurrentVersionSeen("1.0.8")
        XCTAssertTrue(preference.shouldPresent(currentVersion: "2.0.0", hasCompletedOnboarding: true))
    }

    func testProductChangeAnnouncementPresentsOnceAfterOnboarding() {
        let defaults = UserDefaults(suiteName: "ProductChangeAnnouncementTests")!
        defaults.removePersistentDomain(forName: "ProductChangeAnnouncementTests")
        let preference = ProductChangeAnnouncementPreference(userDefaults: defaults)

        XCTAssertFalse(preference.shouldPresent(hasCompletedOnboarding: false))
        XCTAssertTrue(preference.shouldPresent(hasCompletedOnboarding: true))
        preference.markSeen()
        XCTAssertFalse(preference.shouldPresent(hasCompletedOnboarding: true))
    }
}
