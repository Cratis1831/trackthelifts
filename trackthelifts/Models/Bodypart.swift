//
//  Bodypart.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import Foundation
import SwiftData

// All attributes carry default values and every relationship has an inverse because
// CloudKit mirroring requires it — see CloudSyncPreference.
@Model
class Bodypart: Identifiable {
    var id: UUID = UUID()
    var name: String = ""

    // CloudKit sync properties
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isDeleted: Bool = false
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    /// Inverse of `Exercise.bodypart`, required by CloudKit mirroring.
    @Relationship(deleteRule: .nullify, inverse: \Exercise.bodypart)
    var exercises: [Exercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}
