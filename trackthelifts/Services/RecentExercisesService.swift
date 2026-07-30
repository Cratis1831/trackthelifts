//
//  RecentExercisesService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum RecentExercisesService {
    /// Returns the most recently logged distinct exercises, most recent first.
    static func recentExercises(limit: Int = 8, in context: ModelContext) -> [Exercise] {
        var descriptor = FetchDescriptor<ExerciseSet>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200

        do {
            let sets = try context.fetch(descriptor)
            var seen = Set<UUID>()
            var result: [Exercise] = []
            for set in sets {
                guard let exercise = set.exercise else { continue }
                if seen.insert(exercise.id).inserted {
                    result.append(exercise)
                }
                if result.count == limit {
                    break
                }
            }
            return result
        } catch {
            print("Failed to fetch recent exercises: \(error)")
            return []
        }
    }
}
