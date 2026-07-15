//
//  TemplateService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum TemplateService {
    /// Builds a `WorkoutTemplate` from a completed workout, grouping its sets by exercise
    /// (same alphabetical-by-exercise-name convention used throughout the app) and using
    /// the last set performed for each exercise as the target weight/reps.
    static func makeTemplate(from workout: Workout, name: String, in context: ModelContext) throws -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        context.insert(template)

        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        let sortedGroups = grouped.sorted { lhs, rhs in
            (lhs.value.map(\.exerciseOrder).min() ?? .max) < (rhs.value.map(\.exerciseOrder).min() ?? .max)
        }

        var copiedSupersetIDs: [UUID: UUID] = [:]

        for (index, group) in sortedGroups.enumerated() {
            let sets = group.value.sorted { $0.order < $1.order }
            guard let exercise = sets.first?.exercise, let lastSet = sets.last else { continue }

            let templateExercise = WorkoutTemplateExercise(
                order: index,
                targetSets: sets.count,
                targetReps: lastSet.reps,
                targetWeight: lastSet.weight,
                supersetGroupID: lastSet.supersetGroupID.map { oldID in
                    if let existing = copiedSupersetIDs[oldID] { return existing }
                    let fresh = UUID()
                    copiedSupersetIDs[oldID] = fresh
                    return fresh
                },
                template: template,
                exercise: exercise
            )
            context.insert(templateExercise)
            template.templateExercises.append(templateExercise)
        }

        try context.save()

        return template
    }
}
