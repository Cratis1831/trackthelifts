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
    
    func hasActiveWorkout() -> Bool {
        return activeWorkoutID != nil
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
            return workouts.first
        } catch {
            print("Failed to fetch active workout: \(error)")
            return nil
        }
    }
}