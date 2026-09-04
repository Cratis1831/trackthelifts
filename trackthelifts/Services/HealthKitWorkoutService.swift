import Foundation
import HealthKit
import SwiftData

enum HealthKitWorkoutPolicy {
    static func shouldSave(
        isEnabled: Bool,
        isHealthDataAvailable: Bool,
        alreadySaved: Bool
    ) -> Bool {
        isEnabled && isHealthDataAvailable && !alreadySaved
    }
}

/// Opt-in, off by default. Completing a workout writes to Apple Health only when this is on
/// and HealthKit has authorized workout sharing.
@Observable
final class HealthKitPreference {
    static let shared = HealthKitPreference()

    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private let enabledKey = "healthKitSaveWorkoutsEnabled"

    var isEnabled: Bool {
        didSet { userDefaults.set(isEnabled, forKey: enabledKey) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isEnabled = userDefaults.bool(forKey: enabledKey)
    }
}

@MainActor
final class HealthKitWorkoutService {
    static let shared = HealthKitWorkoutService()

    private let store: HKHealthStore?
    private let preference: HealthKitPreference

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    init(
        preference: HealthKitPreference = .shared,
        store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    ) {
        self.preference = preference
        self.store = store
    }

    /// Requests workout write access if needed. Returns whether sharing is authorized.
    func enableIfAuthorized() async -> Bool {
        guard isHealthDataAvailable, let store else {
            preference.isEnabled = false
            return false
        }

        let workoutType = HKObjectType.workoutType()
        switch store.authorizationStatus(for: workoutType) {
        case .sharingAuthorized:
            preference.isEnabled = true
            return true
        case .sharingDenied:
            preference.isEnabled = false
            return false
        case .notDetermined:
            break
        @unknown default:
            break
        }

        do {
            try await store.requestAuthorization(toShare: [workoutType], read: [])
        } catch {
            print("HealthKit authorization failed: \(error)")
            preference.isEnabled = false
            return false
        }

        let authorized = store.authorizationStatus(for: workoutType) == .sharingAuthorized
        preference.isEnabled = authorized
        return authorized
    }

    func saveCompletedWorkout(_ workout: Workout) async {
        guard HealthKitWorkoutPolicy.shouldSave(
            isEnabled: preference.isEnabled,
            isHealthDataAvailable: isHealthDataAvailable,
            alreadySaved: workout.healthKitWorkoutUUID != nil
        ) else { return }
        guard let store else { return }
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }

        let start = workout.createdAt
        let end = max(workout.completedAt ?? .now, start)
        let title = workout.title

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)
            var metadata: [String: Any] = [
                HKMetadataKeyIndoorWorkout: true,
                HKMetadataKeyWorkoutBrandName: "ForgeLyte Lift",
                HKMetadataKeySyncIdentifier: workout.id.uuidString,
                HKMetadataKeySyncVersion: 1,
            ]
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                metadata["ForgeLyteWorkoutTitle"] = trimmedTitle
            }
            try await builder.addMetadata(metadata)
            try await builder.endCollection(at: end)
            guard let saved = try await builder.finishWorkout() else { return }
            workout.healthKitWorkoutUUID = saved.uuid
            workout.updatedAt = .now
        } catch {
            print("Failed to save workout to HealthKit: \(error)")
        }
    }

    func deleteWorkout(uuid: UUID) async {
        guard isHealthDataAvailable, let store else { return }

        do {
            let predicate = HKQuery.predicateForObject(with: uuid)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: []
            )
            let samples = try await descriptor.result(for: store)
            guard !samples.isEmpty else { return }
            try await store.delete(samples)
        } catch {
            print("Failed to delete HealthKit workout: \(error)")
        }
    }
}
