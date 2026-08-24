import XCTest
import SwiftData
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
        XCTAssertFalse(preference.isStoreMirrored)
        XCTAssertNil(preference.lastStoreOpenMessage)
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
        XCTAssertFalse(second.isStoreMirrored, "Live store mirroring is process state, not persisted")
    }

    func testCachedHasProPostsTheSameRebuildNotificationAsTheToggle() {
        let preference = CloudSyncPreference(userDefaults: defaults)
        let toggleExpectation = expectation(forNotification: CloudSyncPreference.didChangeNotification, object: nil)
        preference.isEnabled = true
        wait(for: [toggleExpectation], timeout: 1)

        let proExpectation = expectation(forNotification: CloudSyncPreference.didChangeNotification, object: nil)
        preference.cachedHasPro = true
        wait(for: [proExpectation], timeout: 1)
    }

    func testCachedHasProDoesNotPostWhenUnchanged() {
        let preference = CloudSyncPreference(userDefaults: defaults)
        preference.cachedHasPro = true

        let unexpected = expectation(forNotification: CloudSyncPreference.didChangeNotification, object: nil)
        unexpected.isInverted = true
        preference.cachedHasPro = true
        wait(for: [unexpected], timeout: 0.2)
    }

    func testLocalAndCloudConfigurationsUseSeparateStoreFiles() {
        let schema = Schema([
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
        let local = CloudSyncStoreMigrator.localConfiguration(schema: schema)
        let cloud = CloudSyncStoreMigrator.cloudConfiguration(schema: schema)

        XCTAssertNotEqual(
            local.url,
            cloud.url,
            "CloudKit must use a separate store file so it is never attached to a local-only .store"
        )
        XCTAssertTrue(
            cloud.url.lastPathComponent.contains(CloudSyncStoreMigrator.cloudStoreName),
            "Cloud store file should be named \(CloudSyncStoreMigrator.cloudStoreName)"
        )
        XCTAssertEqual(CloudSyncPreference.containerIdentifier, "iCloud.com.ashkansdev.track-the-lifts")
    }

    func testRelaunchCopyIsTheRequiredForceQuitMessage() {
        XCTAssertEqual(
            CloudSyncPreference.relaunchMessage,
            "Force-quit Track The Lifts and reopen to finish turning on iCloud."
        )
    }
}
