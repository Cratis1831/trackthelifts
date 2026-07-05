import Foundation
import SwiftData

@Observable
class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()
    
    @ObservationIgnored
    private let userDefaults = UserDefaults.standard
    
    var activeWorkoutID: UUID? {
        didSet {
            if let id = activeWorkoutID {
                userDefaults.set(id.uuidString, forKey: "activeWorkoutID")
            } else {
                userDefaults.removeObject(forKey: "activeWorkoutID")
            }
        }
    }
    
    var isWorkoutMinimized: Bool = false {
        didSet {
            userDefaults.set(isWorkoutMinimized, forKey: "isWorkoutMinimized")
        }
    }
    
    private init() {
        if let uuidString = userDefaults.string(forKey: "activeWorkoutID") {
            self.activeWorkoutID = UUID(uuidString: uuidString)
        } else {
            self.activeWorkoutID = nil
        }
        self.isWorkoutMinimized = userDefaults.bool(forKey: "isWorkoutMinimized")
    }
    
    func startWorkout(workoutID: UUID) {
        activeWorkoutID = workoutID
        isWorkoutMinimized = false
    }
    
    func minimizeWorkout() {
        isWorkoutMinimized = true
    }
    
    func resumeWorkout() {
        isWorkoutMinimized = false
    }
    
    func completeWorkout() {
        activeWorkoutID = nil
        isWorkoutMinimized = false
    }
    
    /// Whether there's a genuinely usable active workout — validated against the store, not just
    /// whether an id happens to be cached, so a stale/orphaned pointer can't produce a false positive.
    func hasActiveWorkout(in modelContext: ModelContext) -> Bool {
        getActiveWorkout(from: modelContext) != nil
    }

    func getActiveWorkout(from modelContext: ModelContext) -> Workout? {
        guard let activeWorkoutID = activeWorkoutID else { return nil }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.id == activeWorkoutID && workout.isActive
            }
        )

        do {
            let workouts = try modelContext.fetch(descriptor)
            let workout = workouts.first
            if workout == nil {
                // Stale pointer: the referenced workout no longer exists or isn't active anymore.
                // Clear it so future checks don't keep reporting a phantom active workout.
                self.activeWorkoutID = nil
                self.isWorkoutMinimized = false
            }
            return workout
        } catch {
            print("Failed to fetch active workout: \(error)")
            return nil
        }
    }
}