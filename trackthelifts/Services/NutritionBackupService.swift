//
//  NutritionBackupService.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

/// Pro-only diary restore snapshot. Local SwiftData stays the live diary; Neon holds the last
/// successful upload so a new iPhone or reinstall can recover it. Not live sync.
@Observable
@MainActor
final class NutritionBackupService {
    static let shared = NutritionBackupService()
    static let minimumPushInterval: TimeInterval = 15 * 60
    static let stalePushInterval: TimeInterval = 12 * 60 * 60

    private var container: ModelContainer?
    private var isRunning = false
    @ObservationIgnored
    private let defaults: UserDefaults

    private(set) var isDirty: Bool {
        didSet { defaults.set(isDirty, forKey: Keys.dirty) }
    }

    private(set) var lastSuccessAt: Date? {
        didSet { defaults.set(lastSuccessAt, forKey: Keys.lastSuccess) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.isDirty = userDefaults.bool(forKey: Keys.dirty)
        self.lastSuccessAt = userDefaults.object(forKey: Keys.lastSuccess) as? Date
    }

    func configure(container: ModelContainer) {
        self.container = container
    }

    var lastSuccessCaption: String {
        guard let lastSuccessAt else { return "Not backed up yet" }
        return "Last backup \(lastSuccessAt.formatted(date: .abbreviated, time: .shortened))"
    }

    func markDirty() {
        isDirty = true
    }

    func syncOnForeground() async {
        await restoreIfLocalEmpty()
        await pushIfNeeded(minimumInterval: Self.stalePushInterval)
    }

    func pushIfNeeded(minimumInterval: TimeInterval = minimumPushInterval) async {
        guard isDirty else { return }
        if let lastSuccessAt, Date.now.timeIntervalSince(lastSuccessAt) < minimumInterval {
            return
        }
        await pushNow()
    }

    @discardableResult
    func pushNow() async -> Bool {
        guard RevenueCatService.shared.currentTier == .pro else { return false }
        guard let container, !isRunning else { return false }
        isRunning = true
        defer { isRunning = false }

        do {
            try await ForgeLyteSession.shared.pushNutritionSnapshot(makePayload(from: container))
            isDirty = false
            lastSuccessAt = .now
            incrementRev()
            return true
        } catch ForgeLyteAPIError.proRequired {
            return false
        } catch {
            print("Nutrition backup failed: \(error)")
            return false
        }
    }

    func restoreIfLocalEmpty() async {
        guard RevenueCatService.shared.currentTier == .pro else { return }
        guard let container, !isRunning else { return }
        let context = ModelContext(container)
        guard isLocalDiaryEmpty(context) else { return }

        isRunning = true
        defer { isRunning = false }
        do {
            guard let snapshot = try await ForgeLyteSession.shared.fetchNutritionSnapshot(),
                  !snapshot.isEmpty else { return }
            try replaceLocalDiary(with: snapshot, in: context)
            isDirty = false
            lastSuccessAt = .now
        } catch {
            print("Nutrition restore skipped: \(error)")
        }
    }

    func restoreOverwritingLocal() async throws {
        guard let container else { return }
        guard let snapshot = try await ForgeLyteSession.shared.fetchNutritionSnapshot() else {
            throw ForgeLyteAPIError.server("No nutrition backup exists yet.")
        }
        let context = ModelContext(container)
        try replaceLocalDiary(with: snapshot, in: context)
        isDirty = false
        lastSuccessAt = .now
    }

    func deleteRemoteAndLocal() async {
        if let container {
            let context = ModelContext(container)
            clearLocal(context)
        }
        NutritionPreference.shared.reset()
        isDirty = false
        lastSuccessAt = nil
        defaults.set(1, forKey: Keys.rev)
        guard RevenueCatService.shared.currentTier == .pro else { return }
        do {
            try await ForgeLyteSession.shared.deleteNutritionSnapshot()
        } catch {
            print("Nutrition backup delete failed: \(error)")
        }
    }

    private func makePayload(from container: ModelContainer) throws -> NutritionBackupPayload {
        let context = ModelContext(container)
        let logs = try context.fetch(FetchDescriptor<FoodLog>())
        let foods = try context.fetch(FetchDescriptor<CustomFood>())
        let meals = try context.fetch(FetchDescriptor<SavedMeal>())
        return NutritionBackupPayload.capture(
            logs: logs,
            customFoods: foods,
            savedMeals: meals,
            targets: NutritionPreference.shared,
            clientRev: defaults.integer(forKey: Keys.rev) == 0 ? 1 : defaults.integer(forKey: Keys.rev)
        )
    }

    private func isLocalDiaryEmpty(_ context: ModelContext) -> Bool {
        let logCount = (try? context.fetchCount(FetchDescriptor<FoodLog>())) ?? 0
        let foodCount = (try? context.fetchCount(FetchDescriptor<CustomFood>())) ?? 0
        let mealCount = (try? context.fetchCount(FetchDescriptor<SavedMeal>())) ?? 0
        return logCount == 0 && foodCount == 0 && mealCount == 0 && !NutritionPreference.shared.hasSetTargets
    }

    private func replaceLocalDiary(with snapshot: NutritionBackupPayload, in context: ModelContext) throws {
        clearLocal(context)
        snapshot.logs.forEach { context.insert($0.makeLog()) }
        snapshot.customFoods.forEach { context.insert($0.makeFood()) }
        snapshot.savedMeals.forEach { context.insert($0.makeMeal()) }
        snapshot.targets.apply(to: NutritionPreference.shared)
        try context.save()
        defaults.set(max(snapshot.clientRev, 1), forKey: Keys.rev)
    }

    private func clearLocal(_ context: ModelContext) {
        (try? context.fetch(FetchDescriptor<FoodLog>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<CustomFood>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<SavedMeal>()))?.forEach { context.delete($0) }
        try? context.save()
    }

    private func incrementRev() {
        let current = defaults.integer(forKey: Keys.rev)
        defaults.set(max(current, 1) + 1, forKey: Keys.rev)
    }

    private enum Keys {
        static let dirty = "nutritionBackupDirty"
        static let lastSuccess = "nutritionBackupLastSuccess"
        static let rev = "nutritionBackupClientRev"
    }
}
