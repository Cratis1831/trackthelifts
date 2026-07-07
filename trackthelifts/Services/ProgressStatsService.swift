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

    /// Whether volume points are bucketed by calendar day or by calendar month.
    enum VolumeGranularity {
        case day
        case month
    }

    /// Volume trend plus the granularity its points are bucketed at, so the chart can pick a
    /// matching X axis (individual days vs. months).
    struct VolumeOverTime {
        let granularity: VolumeGranularity
        let points: [WorkoutVolumePoint]
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

    /// Total volume (weight x reps, completed sets only) bucketed over time, oldest to newest.
    ///
    /// While all completed workouts fall within the current calendar month, volume is summed per
    /// day so the chart can show individual days. Once data spans beyond the current month it is
    /// summed per month instead (capped to the most recent `monthLimit` months), so the axis stays
    /// readable as history grows.
    static func volumeOverTime(monthLimit: Int = 12, in context: ModelContext) -> VolumeOverTime {
        let calendar = Calendar.current
        let now = Date()

        let workoutVolumes: [(date: Date, volume: Double)] = completedWorkouts(in: context).map { workout in
            let volume = workout.exerciseSets
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            return (workout.completedAt ?? workout.date, volume)
        }

        guard let earliestDate = workoutVolumes.map(\.date).min() else {
            return VolumeOverTime(granularity: .day, points: [])
        }

        // If the oldest workout is in the current month, everything is — show individual days.
        let allInCurrentMonth = calendar.isDate(earliestDate, equalTo: now, toGranularity: .month)
        let component: Calendar.Component = allInCurrentMonth ? .day : .month
        let granularity: VolumeGranularity = allInCurrentMonth ? .day : .month

        var volumeByBucket: [Date: Double] = [:]
        for entry in workoutVolumes {
            let bucketStart = calendar.dateInterval(of: component, for: entry.date)?.start ?? entry.date
            volumeByBucket[bucketStart, default: 0] += entry.volume
        }

        var points = volumeByBucket
            .map { WorkoutVolumePoint(id: UUID(), date: $0.key, volume: $0.value) }
            .sorted { $0.date < $1.date }

        if granularity == .month {
            points = Array(points.suffix(monthLimit))
        }

        return VolumeOverTime(granularity: granularity, points: points)
    }

    /// Chronological (oldest first) history of completed sets for a given exercise, from
    /// workouts that were actually finished (excludes sets checked off in an abandoned/active
    /// workout that never got a "Finish Workout").
    static func history(for exercise: Exercise, in context: ModelContext) -> [ExerciseHistoryPoint] {
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> {
                $0.exercise.id == exerciseID && $0.isCompleted
                    && $0.workout.completedAt != nil && !$0.workout.isDeleted
            }
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

    /// Best weight and best estimated 1RM ever logged, per exercise, sorted alphabetically. Only
    /// counts sets from workouts that were actually finished.
    static func personalRecords(in context: ModelContext) -> [ExercisePersonalRecord] {
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> {
                $0.isCompleted && $0.workout.completedAt != nil && !$0.workout.isDeleted
            }
        )
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
