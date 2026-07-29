//
//  CloudSyncMergeService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

/// Repairs the one predictable artifact of turning on iCloud sync with data on more than one
/// device: the seeded exercise library (and its body parts) exists independently on every
/// device, so the merged store ends up with duplicate `Exercise`/`Bodypart` rows. Same-named
/// records are merged into a single survivor — every set and routine entry is repointed to the
/// survivor *before* the duplicate is deleted, so no logged history is ever lost. Workouts are
/// never touched: two workouts are always genuinely distinct entries.
enum CloudSyncMergeService {
    /// Runs both merge passes and saves once if anything changed. Idempotent and safe to call
    /// repeatedly (launch + every batch of remote changes).
    static func mergeDuplicates(in context: ModelContext) {
        let mergedExercises = mergeDuplicateExercises(in: context)
        let mergedBodyparts = mergeDuplicateBodyparts(in: context)
        guard mergedExercises || mergedBodyparts else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save after merging synced duplicates: \(error)")
        }
    }

    /// Merges exercises whose names normalize to the same key. Returns true if anything changed.
    private static func mergeDuplicateExercises(in context: ModelContext) -> Bool {
        guard let exercises = try? context.fetch(FetchDescriptor<Exercise>()) else { return false }
        let grouped = Dictionary(grouping: exercises) { ExerciseData.normalizedName($0.name) }
        var didChange = false

        for duplicates in grouped.values where duplicates.count > 1 {
            let ordered = deterministicOrder(duplicates)
            guard let survivor = ordered.first else { continue }

            for duplicate in ordered.dropFirst() {
                for set in duplicate.exerciseSets {
                    set.exercise = survivor
                }
                for templateExercise in duplicate.templateExercises {
                    templateExercise.exercise = survivor
                }
                if survivor.bodypart == nil {
                    survivor.bodypart = duplicate.bodypart
                }
                if survivor.category == .other, duplicate.category != .other {
                    survivor.category = duplicate.category
                }
                context.delete(duplicate)
                didChange = true
            }
        }
        return didChange
    }

    /// Merges body parts whose names normalize to the same key. Returns true if anything changed.
    private static func mergeDuplicateBodyparts(in context: ModelContext) -> Bool {
        guard let bodyparts = try? context.fetch(FetchDescriptor<Bodypart>()) else { return false }
        let grouped = Dictionary(grouping: bodyparts) { ExerciseData.normalizedName($0.name) }
        var didChange = false

        for duplicates in grouped.values where duplicates.count > 1 {
            let ordered = deterministicOrder(duplicates)
            guard let survivor = ordered.first else { continue }

            for duplicate in ordered.dropFirst() {
                for exercise in duplicate.exercises {
                    exercise.bodypart = survivor
                }
                context.delete(duplicate)
                didChange = true
            }
        }
        return didChange
    }

    /// Oldest record first, tie-broken by UUID, so every device converges on the same survivor
    /// regardless of the order in which CloudKit delivers the records.
    private static func deterministicOrder<T>(_ records: [T]) -> [T] where T: PersistentModel {
        records.sorted { lhs, rhs in
            let lhsKey = sortKey(for: lhs)
            let rhsKey = sortKey(for: rhs)
            if lhsKey.0 != rhsKey.0 { return lhsKey.0 < rhsKey.0 }
            return lhsKey.1 < rhsKey.1
        }
    }

    private static func sortKey(for record: some PersistentModel) -> (Date, String) {
        switch record {
        case let exercise as Exercise: (exercise.createdAt, exercise.id.uuidString)
        case let bodypart as Bodypart: (bodypart.createdAt, bodypart.id.uuidString)
        default: (.distantFuture, "")
        }
    }
}
