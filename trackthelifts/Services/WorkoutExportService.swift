//
//  WorkoutExportService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum WorkoutExportService {
    private static let columns = ["Date", "Workout Title", "Exercise", "Body Part", "Set", "Set Type", "Weight", "Unit", "Reps", "Notes"]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Builds a CSV (one row per completed set) of every completed, non-deleted workout, oldest
    /// first. Mirrors the same "what actually counts" filtering already used for Personal
    /// Records/History: completed workouts only, completed sets only.
    static func buildCSV(in context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.completedAt != nil && !$0.isDeleted }
        )
        let workouts = ((try? context.fetch(descriptor)) ?? [])
            .sorted { ($0.completedAt ?? $0.date) < ($1.completedAt ?? $1.date) }

        let unitLabel = WeightUnitPreference.shared.unit.label

        var rows: [[String]] = [columns]
        for workout in workouts {
            let dateString = dateFormatter.string(from: workout.completedAt ?? workout.date)
            let notes = workout.notes ?? ""

            let grouped = Dictionary(grouping: workout.exerciseSets.filter { $0.isCompleted }, by: \.exercise.name)
            let orderedNames = grouped.keys.sorted { name1, name2 in
                let order1 = grouped[name1]?.map(\.exerciseOrder).min() ?? Int.max
                let order2 = grouped[name2]?.map(\.exerciseOrder).min() ?? Int.max
                if order1 != order2 { return order1 < order2 }
                let earliest1 = grouped[name1]?.map(\.createdAt).min() ?? .distantFuture
                let earliest2 = grouped[name2]?.map(\.createdAt).min() ?? .distantFuture
                return earliest1 < earliest2
            }

            for name in orderedNames {
                guard let sets = grouped[name]?.sorted(by: { $0.order < $1.order }) else { continue }
                let bodypart = sets.first?.exercise.bodypart?.name ?? ""

                for (index, set) in sets.enumerated() {
                    rows.append([
                        dateString,
                        workout.title,
                        name,
                        bodypart,
                        "Set \(index + 1)",
                        set.classification.label,
                        set.weight.formattedWeight,
                        unitLabel,
                        String(set.reps),
                        notes,
                    ])
                }
            }
        }

        return rows.map { $0.map(escapeCSVField).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func escapeCSVField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
