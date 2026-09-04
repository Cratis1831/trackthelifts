import XCTest
@testable import trackthelifts

final class HealthKitWorkoutPolicyTests: XCTestCase {
    func testDoesNotSaveWhenDisabled() {
        XCTAssertFalse(HealthKitWorkoutPolicy.shouldSave(
            isEnabled: false,
            isHealthDataAvailable: true,
            alreadySaved: false
        ))
    }

    func testDoesNotSaveWhenHealthDataUnavailable() {
        XCTAssertFalse(HealthKitWorkoutPolicy.shouldSave(
            isEnabled: true,
            isHealthDataAvailable: false,
            alreadySaved: false
        ))
    }

    func testDoesNotSaveWhenAlreadySaved() {
        XCTAssertFalse(HealthKitWorkoutPolicy.shouldSave(
            isEnabled: true,
            isHealthDataAvailable: true,
            alreadySaved: true
        ))
    }

    func testSavesWhenEnabledAvailableAndNew() {
        XCTAssertTrue(HealthKitWorkoutPolicy.shouldSave(
            isEnabled: true,
            isHealthDataAvailable: true,
            alreadySaved: false
        ))
    }
}

final class HealthKitPreferenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "HealthKitPreferenceTests"

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

    func testSaveWorkoutsDefaultsToOff() {
        let preference = HealthKitPreference(userDefaults: defaults)
        XCTAssertFalse(preference.isEnabled)
    }

    func testPreferencePersistsAcrossInstances() {
        let first = HealthKitPreference(userDefaults: defaults)
        first.isEnabled = true

        let second = HealthKitPreference(userDefaults: defaults)
        XCTAssertTrue(second.isEnabled)
    }
}
