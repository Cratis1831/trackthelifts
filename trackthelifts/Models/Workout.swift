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

    /// The per-exercise note for the given exercise within this workout, or "" if none. The note
    /// is stored on one of the exercise's sets (first non-nil in set order) — see
    /// `ExerciseSet.exerciseNote`.
    func exerciseNote(for exerciseName: String) -> String {
        orderedSets(ofExerciseNamed: exerciseName)
            .compactMap(\.exerciseNote)
            .first ?? ""
    }

    /// Writes the per-exercise note onto the exercise's first set (lowest `order`) and clears any
    /// stale copy from its other sets, keeping exactly one carrier. Empty/whitespace-only input
    /// stores `nil` so "no note" round-trips identically for pre- and post-migration sets. The
    /// string is stored untrimmed so a live TextField binding reads back exactly what was typed.
    /// Caller is responsible for saving the context.
    func setExerciseNote(_ note: String, for exerciseName: String) {
        let sets = orderedSets(ofExerciseNamed: exerciseName)
        guard let first = sets.first else { return }
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        if first.exerciseNote != normalized {
            first.exerciseNote = normalized
            first.updatedAt = .now
        }
        for other in sets.dropFirst() where other.exerciseNote != nil {
            other.exerciseNote = nil
            other.updatedAt = .now
        }
    }

    /// Call before deleting `set`: if it carries its exercise's note, move the note onto a
    /// surviving set of the same exercise so deleting one set doesn't silently delete the note.
    /// (When it's the exercise's last set, the note is intentionally deleted with the exercise.)
    func preserveExerciseNote(beforeDeleting set: ExerciseSet) {
        guard let note = set.exerciseNote else { return }
        guard let survivor = orderedSets(ofExerciseNamed: set.exercise.name)
            .first(where: { $0.id != set.id }) else { return }
        survivor.exerciseNote = note
        survivor.updatedAt = .now
        set.exerciseNote = nil
    }

    private func orderedSets(ofExerciseNamed name: String) -> [ExerciseSet] {
        exerciseSets
            .filter { $0.exercise.name == name }
            .sorted { $0.order < $1.order }
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
            let groupNote = sets.compactMap(\.exerciseNote).first

            for (index, previousSet) in sets.enumerated() {
                let newSet = ExerciseSet(
                    weight: previousSet.weight,
                    reps: previousSet.reps,
                    order: index,
                    exerciseOrder: exerciseIndex,
                    exercise: exercise,
                    workout: newWorkout,
                    exerciseNote: index == 0 ? groupNote : nil
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
