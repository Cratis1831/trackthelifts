import XCTest
@testable import trackthelifts

final class AppSupportTests: XCTestCase {
    func testSupportDestinationsAreCentralizedAndCorrect() {
        XCTAssertEqual(AppLinks.manageSubscription.absoluteString, "https://apps.apple.com/account/subscriptions")
        XCTAssertEqual(AppLinks.website.absoluteString, "https://www.forgelyte.com/lift")
        XCTAssertEqual(AppLinks.feedback.absoluteString, "https://forgelyte-lift.userjot.com")
        XCTAssertEqual(
            AppLinks.termsOfService.absoluteString,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
        XCTAssertEqual(
            AppLinks.privacyPolicy.absoluteString,
            "https://www.forgelyte.com/apps/TrackTheLifts/privacy-policy"
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
        XCTAssertEqual(AppVersion.marketingVersion, "1.0.3")
        XCTAssertEqual(AppVersion.buildNumber, "3")
        XCTAssertEqual(ReleaseCatalog.releases.first?.version, AppVersion.marketingVersion)
        XCTAssertFalse(ReleaseCatalog.releases.first?.notes.isEmpty ?? true)
    }
}
