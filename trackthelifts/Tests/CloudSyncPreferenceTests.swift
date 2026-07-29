import XCTest
@testable import trackthelifts

final class CloudSyncPreferenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "CloudSyncPreferenceTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testSyncDefaultsToOffForExistingAndNewUsers() {
        let preference = CloudSyncPreference(userDefaults: defaults)
        XCTAssertFalse(preference.isEnabled)
        XCTAssertFalse(preference.isSyncActive)
        XCTAssertFalse(preference.hasSeenAnnouncement)
    }

    func testSyncActiveRequiresBothOptInAndPro() {
        let preference = CloudSyncPreference(userDefaults: defaults)

        preference.isEnabled = true
        XCTAssertFalse(preference.isSyncActive, "Opt-in without Pro must not activate sync")

        preference.isEnabled = false
        preference.cachedHasPro = true
        XCTAssertFalse(preference.isSyncActive, "Pro without opt-in must not activate sync")

        preference.isEnabled = true
        XCTAssertTrue(preference.isSyncActive)
    }

    func testProLapseDeactivatesSyncButKeepsOptIn() {
        let preference = CloudSyncPreference(userDefaults: defaults)
        preference.isEnabled = true
        preference.cachedHasPro = true
        XCTAssertTrue(preference.isSyncActive)

        preference.cachedHasPro = false
        XCTAssertFalse(preference.isSyncActive)
        XCTAssertTrue(preference.isEnabled, "The opt-in survives a lapse so sync resumes with Pro")
    }

    func testPreferencePersistsAcrossInstances() {
        let first = CloudSyncPreference(userDefaults: defaults)
        first.isEnabled = true
        first.cachedHasPro = true
        first.hasSeenAnnouncement = true

        let second = CloudSyncPreference(userDefaults: defaults)
        XCTAssertTrue(second.isEnabled)
        XCTAssertTrue(second.cachedHasPro)
        XCTAssertTrue(second.hasSeenAnnouncement)
        XCTAssertTrue(second.isSyncActive)
    }
}
