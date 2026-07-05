import SwiftUI
import SwiftData

@Model
class Workout {
    var id: UUID
    var title: String
    var date: Date
    var notes: String?
    var isActive: Bool
    var completedAt: Date?
    
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
        isActive: Bool = true,
        completedAt: Date? = nil,
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
        self.isActive = isActive
        self.completedAt = completedAt
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

    /// Creates a new in-progress `Workout` that repeats this (typically completed) workout's
    /// exercises and set count, carrying over the previous weight/reps as a starting point
    /// but resetting completion so the user logs each set fresh. Preserves the original
    /// workout's exercise order rather than re-alphabetizing it.
    func duplicate(in context: ModelContext) -> Workout {
        let newWorkout = Workout(title: title, date: .now)
        context.insert(newWorkout)

        let grouped = Dictionary(grouping: exerciseSets, by: \.exercise.name)
        let sortedNames = grouped.keys.sorted { name1, name2 in
            let order1 = grouped[name1]?.map(\.exerciseOrder).min() ?? Int.max
            let order2 = grouped[name2]?.map(\.exerciseOrder).min() ?? Int.max
            if order1 != order2 { return order1 < order2 }
            let earliest1 = grouped[name1]?.map(\.createdAt).min() ?? .distantFuture
            let earliest2 = grouped[name2]?.map(\.createdAt).min() ?? .distantFuture
            return earliest1 < earliest2
        }

        for (exerciseIndex, name) in sortedNames.enumerated() {
            guard let group = grouped[name] else { continue }
            let sets = group.sorted { $0.order < $1.order }
            guard let exercise = sets.first?.exercise else { continue }

            for (index, previousSet) in sets.enumerated() {
                let newSet = ExerciseSet(
                    weight: previousSet.weight,
                    reps: previousSet.reps,
                    order: index,
                    exerciseOrder: exerciseIndex,
                    exercise: exercise,
                    workout: newWorkout
                )
                context.insert(newSet)
                newWorkout.exerciseSets.append(newSet)
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to duplicate workout: \(error)")
        }

        return newWorkout
    }
}
