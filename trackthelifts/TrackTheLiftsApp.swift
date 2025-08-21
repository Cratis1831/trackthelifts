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
    
    init() {
        // Configure RevenueCat on app launch
        Task {
            await RevenueCatService.shared.configure(apiKey: "appl_ZGXYqMVdOsnpcpehmvbnAmriXcW")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(revenueCatService)
        }
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self,
        ])
    }
}
