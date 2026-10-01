//
//  WorkoutShareSummary.swift
//  TrackTheLifts
//

import Foundation

/// A snapshot of a finished workout shaped for the social share card. Built once from SwiftData
/// so the card can be rendered (and re-rendered per style) without touching the model context.
struct WorkoutShareSummary: Equatable {
    struct ExerciseLine: Equatable, Identifiable {
        let name: String
        let setCount: Int
        let topSet: LiftPerformance

        var id: String { name }
    }

    let workoutName: String
    let date: Date
    let duration: TimeInterval
    let exerciseCount: Int
    let completedSetCount: Int
    let totalReps: Int
    let totalVolume: Double
    let unitLabel: String
    let exercises: [ExerciseLine]
    let personalRecords: [WorkoutPersonalRecord]

    init(workout: Workout, personalRecords: [WorkoutPersonalRecord], unitLabel: String) {
        let completedSets = (workout.exerciseSets ?? []).filter(\.isCompleted)
        let grouped = Dictionary(grouping: completedSets, by: \.exerciseName)

        workoutName = workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : workout.title
        date = workout.completedAt ?? workout.date
        duration = max(0, (workout.completedAt ?? .now).timeIntervalSince(workout.createdAt))
        exerciseCount = grouped.count
        completedSetCount = completedSets.count
        totalReps = completedSets.reduce(0) { $0 + $1.reps }
        totalVolume = completedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        self.unitLabel = unitLabel
        self.personalRecords = personalRecords
        exercises = grouped
            .sorted { lhs, rhs in
                let order1 = lhs.value.map(\.exerciseOrder).min() ?? Int.max
                let order2 = rhs.value.map(\.exerciseOrder).min() ?? Int.max
                if order1 != order2 { return order1 < order2 }
                return lhs.key < rhs.key
            }
            .compactMap { entry in
                let performances = entry.value.map { LiftPerformance(weight: $0.weight, reps: $0.reps) }
                guard let topSet = performances.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }) else { return nil }
                return ExerciseLine(name: entry.key, setCount: entry.value.count, topSet: topSet)
            }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
        }
        return "\(minutes)m"
    }

    /// Volume compacted for a hero number: 12,450 → "12.4K", 1,250,000 → "1.25M".
    var formattedVolume: String {
        Self.compactNumber(totalVolume)
    }

    static func compactNumber(_ value: Double) -> String {
        switch value {
        case 1_000_000...:
            return trimmed(value / 1_000_000, decimals: 2) + "M"
        case 10_000...:
            return trimmed(value / 1_000, decimals: 1) + "K"
        default:
            return Int(value.rounded()).formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
        }
    }

    private static func trimmed(_ value: Double, decimals: Int) -> String {
        let factor = pow(10, Double(decimals))
        let truncated = (value * factor).rounded(.down) / factor
        var text = String(format: "%.\(decimals)f", truncated)
        while text.contains("."), text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    func formattedSet(_ performance: LiftPerformance) -> String {
        performance.weight > 0
            ? "\(performance.weight.formattedWeight) \(unitLabel) × \(performance.reps)"
            : "\(performance.reps) reps"
    }
}

extension PRKind {
    var shareLabel: String {
        switch self {
        case .weight: return "Heaviest lift"
        case .estimated1RM: return "Est. 1RM"
        case .volume: return "Best set volume"
        }
    }
}
