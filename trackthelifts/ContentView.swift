//
//  ContentView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Profile", systemImage: "person") {
                ProfileView()
            }

            Tab("History", systemImage: "clock") {
                HistoryView()
            }

            Tab("Create Workout", systemImage: "plus") {
                WorkoutView()
            }

            Tab("Exercises", systemImage: "dumbbell") {
                ExerciseListView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(.orange)
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self
        ])
}
