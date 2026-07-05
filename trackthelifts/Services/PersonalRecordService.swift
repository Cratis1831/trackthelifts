//
//  PersonalRecordService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum PRKind {
    case weight
    case estimated1RM
}

enum PersonalRecordService {
    /// Epley estimated one-rep max.
    static func estimated1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30.0)
    }

    /// Returns the kind of personal record `set` represents, comparing against every other
    /// completed set previously logged for the same exercise in a workout that was actually
    /// finished. Returns nil if it isn't a new best.
    static func personalRecord(for set: ExerciseSet, in context: ModelContext) -> PRKind? {
        let exerciseID = set.exercise.id
        let setID = set.id
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { other in
                other.exercise.id == exerciseID && other.isCompleted && other.id != setID
                    && other.workout.completedAt != nil && !other.workout.isDeleted
            }
        )

        guard let history = try? context.fetch(descriptor), !history.isEmpty else {
            // No prior completed sets for this exercise - not a meaningful PR yet.
            return nil
        }

        let bestWeight = history.map(\.weight).max() ?? 0
        let best1RM = history.map { estimated1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0

        let setEstimated1RM = estimated1RM(weight: set.weight, reps: set.reps)

        if set.weight > bestWeight {
            return .weight
        } else if setEstimated1RM > best1RM {
            return .estimated1RM
        }
        return nil
    }
}
