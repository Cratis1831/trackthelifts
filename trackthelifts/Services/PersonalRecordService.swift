//
//  PersonalRecordService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum PRKind {
    case weight
    case estimated1RM
    case volume
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
        guard let exerciseID = set.exercise?.id else { return nil }
        let setID = set.id
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { other in
                other.exercise?.id == exerciseID && other.isCompleted && other.id != setID
                    && other.workout?.completedAt != nil && other.workout?.isDeleted == false
            }
        )

        guard let history = try? context.fetch(descriptor), !history.isEmpty else {
            // No prior completed sets for this exercise - not a meaningful PR yet.
            return nil
        }

        let bestWeight = history.map(\.weight).max() ?? 0
        let best1RM = history.map { estimated1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
        let bestVolume = history.map { $0.weight * Double($0.reps) }.max() ?? 0

        let setEstimated1RM = estimated1RM(weight: set.weight, reps: set.reps)
        let setVolume = set.weight * Double(set.reps)

        if set.weight > bestWeight {
            return .weight
        } else if setEstimated1RM > best1RM {
            return .estimated1RM
        } else if setVolume > bestVolume {
            return .volume
        }
        return nil
    }
}

/// A single weight/reps pairing, decoupled from SwiftData so PR comparisons stay pure and testable.
struct LiftPerformance: Equatable {
    let weight: Double
    let reps: Int

    var estimated1RM: Double { PersonalRecordService.estimated1RM(weight: weight, reps: reps) }
    var volume: Double { weight * Double(reps) }
}

/// The headline personal record an exercise earned within one workout.
struct WorkoutPersonalRecord: Equatable, Identifiable {
    let exerciseName: String
    let kind: PRKind
    let performance: LiftPerformance

    var id: String { exerciseName }
}

extension PersonalRecordService {
    /// The best record `sets` beat relative to `history`, preferring a heavier weight, then a
    /// higher estimated 1RM, then more single-set volume (the same priority as live PR detection).
    /// Returns nil when there is no prior history, matching `personalRecord(for:in:)`.
    static func bestRecord(among sets: [LiftPerformance], history: [LiftPerformance]) -> (kind: PRKind, performance: LiftPerformance)? {
        guard !sets.isEmpty, !history.isEmpty else { return nil }

        let bestWeight = history.map(\.weight).max() ?? 0
        let best1RM = history.map(\.estimated1RM).max() ?? 0
        let bestVolume = history.map(\.volume).max() ?? 0

        if let heaviest = sets.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }), heaviest.weight > bestWeight {
            return (.weight, heaviest)
        }
        if let strongest = sets.max(by: { $0.estimated1RM < $1.estimated1RM }), strongest.estimated1RM > best1RM {
            return (.estimated1RM, strongest)
        }
        if let biggest = sets.max(by: { $0.volume < $1.volume }), biggest.volume > bestVolume {
            return (.volume, biggest)
        }
        return nil
    }

    /// Personal records earned in `workout`, one per exercise, compared only against workouts that
    /// were finished before it. Works both right after completion and for older workouts in History.
    static func personalRecords(in workout: Workout, context: ModelContext) -> [WorkoutPersonalRecord] {
        let workoutID = workout.id
        let cutoff = workout.completedAt ?? .now
        let completedSets = (workout.exerciseSets ?? []).filter { $0.isCompleted && $0.reps > 0 }
        let setsByExercise = Dictionary(grouping: completedSets) { $0.exercise?.id }

        var records: [(order: Int, record: WorkoutPersonalRecord)] = []
        for (groupExerciseID, sets) in setsByExercise {
            guard let exerciseID = groupExerciseID else { continue }
            let descriptor = FetchDescriptor<ExerciseSet>(
                predicate: #Predicate<ExerciseSet> { other in
                    other.exercise?.id == exerciseID && other.isCompleted
                        && other.workout?.completedAt != nil && other.workout?.isDeleted == false
                }
            )
            let history = ((try? context.fetch(descriptor)) ?? [])
                .filter { other in
                    guard let otherWorkout = other.workout, otherWorkout.id != workoutID,
                          let completedAt = otherWorkout.completedAt else { return false }
                    return completedAt < cutoff
                }
                .map { LiftPerformance(weight: $0.weight, reps: $0.reps) }

            let performances = sets.map { LiftPerformance(weight: $0.weight, reps: $0.reps) }
            guard let best = bestRecord(among: performances, history: history) else { continue }
            records.append((
                order: sets.map(\.exerciseOrder).min() ?? Int.max,
                record: WorkoutPersonalRecord(
                    exerciseName: sets[0].exerciseName,
                    kind: best.kind,
                    performance: best.performance
                )
            ))
        }
        return records.sorted { $0.order < $1.order }.map(\.record)
    }
}
