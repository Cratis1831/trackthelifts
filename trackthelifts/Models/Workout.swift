import SwiftUI
import SwiftData

@Model
class Workout {
    var id: UUID
    var title: String
    var date: Date
    var notes: String?
    
    // CloudKit sync properties
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var exerciseSets: [ExerciseSet] = []

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}

extension Workout {
    func addExercise(workout: Workout, exercise: Exercise, order: Int) {
        let newExercise = ExerciseSet(weight: 0, reps: 0, order: order, exercise: exercise, workout: workout)
        exerciseSets.append(newExercise)
    }
}
