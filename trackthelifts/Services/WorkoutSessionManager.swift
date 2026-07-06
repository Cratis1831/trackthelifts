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

        // On a fresh process launch nothing is presenting the workout sheet yet, so any workout
        // that was still active when the app last terminated — including a crash mid-set — must be
        // treated as minimized. Otherwise the resume banner and play button stay hidden while the
        // "workout in progress" guard still fires, stranding the user with a phantom active workout
        // they can't reach or clear. If the id turns out to be stale, `getActiveWorkout` clears both
        // flags on the next lookup.
        self.isWorkoutMinimized = activeWorkoutID != nil
            ? true
            : userDefaults.bool(forKey: "isWorkoutMinimized")
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

    /// Enforces the app's "at most one active workout" invariant. Earlier builds could leave a
    /// canceled or crashed workout persisted as `isActive` without clearing the session, so
    /// abandoned workouts that the session no longer points to would linger in the store forever
    /// (invisible to History, which only shows completed workouts). Any active workout whose id
    /// isn't the current session pointer is unreachable, so deactivate it. Runs once on launch.
    func reconcileOrphanedActiveWorkouts(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.isActive }
        )
        guard let activeWorkouts = try? modelContext.fetch(descriptor) else { return }

        var didChange = false
        for workout in activeWorkouts where workout.id != activeWorkoutID {
            workout.isActive = false
            workout.updatedAt = .now
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
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