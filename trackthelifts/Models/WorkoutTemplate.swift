//
//  WorkoutTemplate.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

@Model
class WorkoutTemplate {
    var id: UUID
    var name: String
    var notes: String?

    // CloudKit sync properties
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplateExercise.template)
    var templateExercises: [WorkoutTemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}

extension WorkoutTemplate {
    /// Creates a new in-progress `Workout` pre-seeded with this template's exercises,
    /// each given `targetSets` empty `ExerciseSet`s at the template's target weight/reps.
    func instantiateWorkout(in context: ModelContext) -> Workout {
        let workout = Workout(title: name, date: .now)
        context.insert(workout)

        var copiedSupersetIDs: [UUID: UUID] = [:]

        for (exerciseIndex, templateExercise) in templateExercises.sorted(by: { $0.order < $1.order }).enumerated() {
            for setIndex in 0..<max(templateExercise.targetSets, 1) {
                let set = ExerciseSet(
                    weight: templateExercise.targetWeight,
                    reps: templateExercise.targetReps,
                    order: setIndex,
                    exerciseOrder: exerciseIndex,
                    exercise: templateExercise.exercise,
                    workout: workout,
                    supersetGroupID: templateExercise.supersetGroupID.map { oldID in
                        if let existing = copiedSupersetIDs[oldID] { return existing }
                        let fresh = UUID()
                        copiedSupersetIDs[oldID] = fresh
                        return fresh
                    }
                )
                context.insert(set)
                workout.exerciseSets.append(set)
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to instantiate workout from template: \(error)")
        }

        return workout
    }

    /// Creates a copy of this template (name suffixed "Copy") with the same exercises/targets.
    func duplicateTemplate(in context: ModelContext) -> WorkoutTemplate {
        let copy = WorkoutTemplate(name: "\(name) Copy", notes: notes)
        context.insert(copy)

        var copiedSupersetIDs: [UUID: UUID] = [:]

        for templateExercise in templateExercises.sorted(by: { $0.order < $1.order }) {
            let newTemplateExercise = WorkoutTemplateExercise(
                order: templateExercise.order,
                targetSets: templateExercise.targetSets,
                targetReps: templateExercise.targetReps,
                targetWeight: templateExercise.targetWeight,
                supersetGroupID: templateExercise.supersetGroupID.map { oldID in
                    if let existing = copiedSupersetIDs[oldID] { return existing }
                    let fresh = UUID()
                    copiedSupersetIDs[oldID] = fresh
                    return fresh
                },
                template: copy,
                exercise: templateExercise.exercise
            )
            context.insert(newTemplateExercise)
            copy.templateExercises.append(newTemplateExercise)
        }

        do {
            try context.save()
        } catch {
            print("Failed to duplicate template: \(error)")
        }

        return copy
    }
}
