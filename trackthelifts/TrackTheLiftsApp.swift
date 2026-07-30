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
                    rebuildModelContainer()
                }
        }
        .modelContainer(modelContainer)
    }

    /// Reopens the same on-disk store with CloudKit mirroring switched on or off after the user
    /// toggles iCloud sync. Pending edits are saved first; `@Query` views refetch from the new
    /// container automatically.
    private func rebuildModelContainer() {
        try? modelContainer.mainContext.save()
        modelContainer = Self.makeModelContainer(syncActive: CloudSyncPreference.shared.isSyncActive)
    }

    /// Opens the app's store, CloudKit-mirrored when sync is active, local-only otherwise. Both
    /// configurations point at the same default store file, so flipping sync never migrates or
    /// discards local data. `cloudKitDatabase` is always passed explicitly — once the iCloud
    /// entitlement exists, the `.automatic` default would silently mirror for everyone.
    private static func makeModelContainer(syncActive: Bool) -> ModelContainer {
        let schema = Schema([
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])

        if syncActive {
            do {
                let cloudConfiguration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(CloudSyncPreference.containerIdentifier)
                )
                return try ModelContainer(for: schema, configurations: [cloudConfiguration])
            } catch {
                // Never block access to local data because CloudKit couldn't start (no iCloud
                // account, entitlement not provisioned, etc.) — fall back to the local store.
                print("Failed to open CloudKit-backed store, falling back to local: \(error)")
            }
        }

        do {
            let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Failed to open the local model store: \(error)")
        }
    }
}
