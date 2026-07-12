//
//  WorkoutTemplateExercise.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

@Model
class WorkoutTemplateExercise {
    var id: UUID
    var order: Int
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double
    var supersetGroupID: UUID?

    // CloudKit sync properties
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship var template: WorkoutTemplate
    @Relationship var exercise: Exercise

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
