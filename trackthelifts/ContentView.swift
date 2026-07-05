//
//  ContentView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

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
        .toolbarColorScheme(.dark, for: .tabBar)
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { isPresented in hasCompletedOnboarding = !isPresented }
        )) {
            OnboardingView()
        }
        .onAppear {
            UIApplication.shared.enableTapToDismissKeyboard()
            ExerciseData.seedIfNeeded(in: modelContext)
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
