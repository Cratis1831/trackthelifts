//
//  ProgressStatsService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum ProgressStatsService {
    struct WeeklyCount: Identifiable {
        let id = UUID()
        let weekStart: Date
        let count: Int
    }

    struct WorkoutVolumePoint: Identifiable {
        let id: UUID
        let date: Date
        let volume: Double
    }

    struct ExerciseHistoryPoint: Identifiable {
        let id: UUID
        let date: Date
        let weight: Double
        let reps: Int

        var estimated1RM: Double {
            PersonalRecordService.estimated1RM(weight: weight, reps: reps)
        }
    }

    struct ExercisePersonalRecord: Identifiable {
        let id: UUID
        let exercise: Exercise
        let bestWeight: Double
        let bestWeightReps: Int
        let best1RM: Double
    }

    private static func completedWorkouts(in context: ModelContext) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.completedAt != nil && !$0.isDeleted }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Count of completed workouts per week, oldest to newest, for the last `weeks` weeks (including this week).
    static func weeklyWorkoutCounts(weeks: Int = 8, in context: ModelContext) -> [WeeklyCount] {
        let calendar = Calendar.current
        let now = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        var countsByWeekStart: [Date: Int] = [:]
        for workout in completedWorkouts(in: context) {
            guard let completedAt = workout.completedAt,
                  let weekStart = calendar.dateInterval(of: .weekOfYear, for: completedAt)?.start else { continue }
            countsByWeekStart[weekStart, default: 0] += 1
        }

        return (0..<weeks).compactMap { offset -> WeeklyCount? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1 - offset), to: currentWeekStart) else {
                return nil
            }
            return WeeklyCount(weekStart: weekStart, count: countsByWeekStart[weekStart] ?? 0)
        }
    }

    /// Total volume (weight x reps, completed sets only) for the most recent `limit` completed workouts, oldest to newest.
    static func volumeOverTime(limit: Int = 12, in context: ModelContext) -> [WorkoutVolumePoint] {
        let sorted = completedWorkouts(in: context).sorted {
            ($0.completedAt ?? $0.date) < ($1.completedAt ?? $1.date)
        }
        let recent = sorted.suffix(limit)
        return recent.map { workout in
            let volume = workout.exerciseSets
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            return WorkoutVolumePoint(id: workout.id, date: workout.completedAt ?? workout.date, volume: volume)
        }
    }

    /// Chronological (oldest first) history of completed sets for a given exercise.
    static func history(for exercise: Exercise, in context: ModelContext) -> [ExerciseHistoryPoint] {
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { $0.exercise.id == exerciseID && $0.isCompleted }
        )
        guard let sets = try? context.fetch(descriptor) else { return [] }
        return sets
            .map { set in
                ExerciseHistoryPoint(
                    id: set.id,
                    date: set.workout.completedAt ?? set.updatedAt,
                    weight: set.weight,
                    reps: set.reps
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// Best weight and best estimated 1RM ever logged, per exercise, sorted alphabetically.
    static func personalRecords(in context: ModelContext) -> [ExercisePersonalRecord] {
        let descriptor = FetchDescriptor<ExerciseSet>(predicate: #Predicate<ExerciseSet> { $0.isCompleted })
        guard let sets = try? context.fetch(descriptor), !sets.isEmpty else { return [] }

        let groupedByExerciseID = Dictionary(grouping: sets, by: { $0.exercise.id })
        return groupedByExerciseID.compactMap { _, sets -> ExercisePersonalRecord? in
            guard let exercise = sets.first?.exercise,
                  let bestWeightSet = sets.max(by: { $0.weight < $1.weight }) else { return nil }
            let best1RM = sets.map { PersonalRecordService.estimated1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            return ExercisePersonalRecord(
                id: exercise.id,
                exercise: exercise,
                bestWeight: bestWeightSet.weight,
                bestWeightReps: bestWeightSet.reps,
                best1RM: best1RM
            )
        }
        .sorted { $0.exercise.name.localizedCaseInsensitiveCompare($1.exercise.name) == .orderedAscending }
    }
}
