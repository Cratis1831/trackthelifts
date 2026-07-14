import XCTest
@testable import trackthelifts

final class AppSupportTests: XCTestCase {
    func testSupportDestinationsAreCentralizedAndCorrect() {
        XCTAssertEqual(AppLinks.manageSubscription.absoluteString, "https://apps.apple.com/account/subscriptions")
        XCTAssertEqual(AppLinks.website.absoluteString, "https://www.forgelyte.com/lift")
        XCTAssertEqual(AppLinks.feedback.absoluteString, "https://forgelyte-lift.userjot.com")
    }

    func testShareMessageIncludesBrandAndWebsite() {
        XCTAssertTrue(AppLinks.shareMessage.contains("ForgeLyte Lift"))
        XCTAssertTrue(AppLinks.shareMessage.contains(AppLinks.website.absoluteString))
    }

    func testReviewUsesSystemFallbackUntilAppStoreIDIsConfigured() {
        XCTAssertNil(AppLinks.appStoreReview)
    }

    func testCurrentVersionAndChangelogMatchReleaseBuildSettings() {
        XCTAssertEqual(AppVersion.marketingVersion, "1.0.3")
        XCTAssertEqual(AppVersion.buildNumber, "3")
        XCTAssertEqual(ReleaseCatalog.releases.first?.version, AppVersion.marketingVersion)
        XCTAssertFalse(ReleaseCatalog.releases.first?.notes.isEmpty ?? true)
    }
}
