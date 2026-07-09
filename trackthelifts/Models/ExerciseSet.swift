//
//  ExerciseSet.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import Foundation
import SwiftData

@Model
class ExerciseSet {
    var id: UUID
    var weight: Double
    var reps: Int
    var order: Int
    /// Position of this set's exercise within the workout (shared by every set of that
    /// exercise), so exercises can be drag-reordered independently of when each set was logged.
    var exerciseOrder: Int = 0
    var isCompleted: Bool
    /// Warm-up / working / failure classification for this specific set. Optional at the storage
    /// layer because SwiftData's lightweight migration does not backfill a declared enum default
    /// into rows written before this column existed — those rows persist `NULL`, and reading a
    /// non-optional enum from `NULL` force-casts and crashes. Keeping it optional lets old sets
    /// read back as `nil`; use `classification` to get the resolved `.working` default everywhere.
    var setType: SetClassification? = SetClassification.working

    /// The set's classification with the legacy/default fallback applied. Read this instead of
    /// `setType` so pre-migration sets (stored `nil`) behave as working sets.
    var classification: SetClassification {
        setType ?? .working
    }

    /// Optional user note for this set's exercise within this specific workout (e.g. "felt heavy,
    /// drop 5 lbs next time"). Scoped to the exercise-in-this-workout — distinct from the
    /// workout-level `Workout.notes` and from the global `Exercise` catalog entry. By convention
    /// only one set per (workout, exercise) group carries the note, so read/write it through
    /// `Workout.exerciseNote(for:)` / `Workout.setExerciseNote(_:for:)` rather than directly.
    /// Optional with a `nil` default so SwiftData's lightweight migration can add the column in
    /// place: sets written before this property existed persist `NULL` and read back as `nil`
    /// (no note) instead of crashing.
    var exerciseNote: String?

    // CloudKit sync properties
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship var exercise: Exercise
    @Relationship var workout: Workout

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        order: Int,
        exerciseOrder: Int = 0,
        exercise: Exercise,
        workout: Workout,
        isCompleted: Bool = false,
        setType: SetClassification = .working,
        exerciseNote: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.order = order
        self.exerciseOrder = exerciseOrder
        self.exercise = exercise
        self.workout = workout
        self.isCompleted = isCompleted
        self.setType = setType
        self.exerciseNote = exerciseNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}

