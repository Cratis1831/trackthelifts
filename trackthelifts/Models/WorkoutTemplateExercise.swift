//
//  WorkoutTemplateExercise.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

// All attributes carry default values and to-one relationships are optional because
// CloudKit mirroring requires it — see CloudSyncPreference. App code always assigns
// `template`/`exercise` at creation; they can only be nil transiently for records that
// arrive from CloudKit before their related records do.
@Model
class WorkoutTemplateExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var targetSets: Int = 0
    var targetReps: Int = 0
    var targetWeight: Double = 0
    var supersetGroupID: UUID?

    // CloudKit sync properties
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isDeleted: Bool = false
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship var template: WorkoutTemplate?
    @Relationship var exercise: Exercise?

    init(
        id: UUID = UUID(),
        order: Int,
        targetSets: Int,
        targetReps: Int,
        targetWeight: Double,
        supersetGroupID: UUID? = nil,
        template: WorkoutTemplate,
        exercise: Exercise,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.supersetGroupID = supersetGroupID
        self.template = template
        self.exercise = exercise
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}
