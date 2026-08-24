//
//  TrackTheLiftsApp.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

@main
struct TrackTheLiftsApp: App {
    @StateObject private var revenueCatService = RevenueCatService.shared
    @State private var modelContainer: ModelContainer

    init() {
        AnalyticsService.initialize()

        // Configure RevenueCat on app launch
        Task {
            await RevenueCatService.shared.configure(apiKey: "appl_ZGXYqMVdOsnpcpehmvbnAmriXcW")
        }

        _modelContainer = State(initialValue: Self.makeModelContainer(
            syncActive: CloudSyncPreference.shared.isSyncActive
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(revenueCatService)
                .preferredColorScheme(.dark)
                .onReceive(
                    NotificationCenter.default.publisher(for: CloudSyncPreference.didChangeNotification)
                        .receive(on: DispatchQueue.main)
                ) { _ in
                    handleCloudSyncPreferenceChange()
                }
        }
        .modelContainer(modelContainer)
    }

    /// CloudKit cannot be opened in a process that already opened the local schema, so a
    /// mid-session opt-in (or Pro arriving after launch) snapshots local data and asks for a
    /// force-quit. The container is only chosen on cold launch.
    private func handleCloudSyncPreferenceChange() {
        try? modelContainer.mainContext.save()
        let preference = CloudSyncPreference.shared

        if !preference.isEnabled {
            CloudSyncStoreMigrator.clearPendingSnapshot()
            if preference.lastStoreOpenMessage == CloudSyncPreference.relaunchMessage {
                preference.lastStoreOpenMessage = nil
            }
            return
        }

        guard preference.isSyncActive, !preference.isStoreMirrored else { return }

        do {
            try CloudSyncStoreMigrator.writeSnapshot(from: modelContainer.mainContext)
            preference.lastStoreOpenMessage = CloudSyncPreference.relaunchMessage
        } catch {
            preference.lastStoreOpenMessage = error.localizedDescription
        }
    }

    /// Opens either the CloudKit store or the local-only store. They are separate files;
    /// CloudKit is never attached to a store that was created with `cloudKitDatabase: .none`.
    /// `cloudKitDatabase` is always passed explicitly — once the iCloud entitlement exists,
    /// the `.automatic` default would silently mirror for everyone.
    private static func makeModelContainer(syncActive: Bool) -> ModelContainer {
        let schema = Schema([
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
        let preference = CloudSyncPreference.shared
        preference.isStoreMirrored = false

        let localConfiguration = CloudSyncStoreMigrator.localConfiguration(schema: schema)
        let cloudConfiguration = CloudSyncStoreMigrator.cloudConfiguration(schema: schema)
        let shouldOpenCloudKit = syncActive && CloudSyncStoreMigrator.shouldOpenCloudKitStore(
            localStoreExists: CloudSyncStoreMigrator.storeExists(localConfiguration),
            cloudStoreExists: CloudSyncStoreMigrator.storeExists(cloudConfiguration),
            hasPendingImport: CloudSyncStoreMigrator.hasPendingImport()
        )

        if shouldOpenCloudKit {
            do {
                let container = try ModelContainer(for: schema, configurations: [cloudConfiguration])
                preference.isStoreMirrored = true
                importPendingSnapshotIfNeeded(into: container.mainContext, preference: preference)
                return container
            } catch {
                print("Failed to open CloudKit-backed store, falling back to local: \(error)")
                preference.lastStoreOpenMessage = error.localizedDescription
                preference.isStoreMirrored = false
            }
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [localConfiguration])
            if syncActive, !preference.isStoreMirrored {
                snapshotLocalStoreForCloudKitActivation(
                    from: container.mainContext,
                    preference: preference
                )
            } else if !syncActive {
                preference.lastStoreOpenMessage = nil
            }
            return container
        } catch {
            fatalError("Failed to open the local model store: \(error)")
        }
    }

    private static func importPendingSnapshotIfNeeded(
        into context: ModelContext,
        preference: CloudSyncPreference
    ) {
        guard CloudSyncStoreMigrator.hasPendingImport() else {
            preference.lastStoreOpenMessage = nil
            return
        }
        do {
            try CloudSyncStoreMigrator.importPendingSnapshot(into: context)
            CloudSyncMergeService.mergeDuplicates(in: context)
            preference.lastStoreOpenMessage = nil
        } catch {
            preference.lastStoreOpenMessage = error.localizedDescription
        }
    }

    private static func snapshotLocalStoreForCloudKitActivation(
        from context: ModelContext,
        preference: CloudSyncPreference
    ) {
        do {
            try CloudSyncStoreMigrator.writeSnapshot(from: context)
            if preference.lastStoreOpenMessage == nil {
                preference.lastStoreOpenMessage = CloudSyncPreference.relaunchMessage
            }
        } catch {
            if preference.lastStoreOpenMessage == nil {
                preference.lastStoreOpenMessage = error.localizedDescription
            }
        }
    }
}
