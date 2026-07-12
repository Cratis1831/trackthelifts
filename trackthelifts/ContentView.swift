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
        ZStack {
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
            .tint(.appAccent)
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbarBackground(Color.appSurface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            // Onboarding is a plain overlay rather than a fullScreenCover: presenting a cover
            // from a computed binding during the app's very first frame can fail and write
            // `false` back through the binding, permanently marking onboarding completed before
            // a new user ever saw it.
            if !hasCompletedOnboarding {
                OnboardingView()
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: hasCompletedOnboarding)
        .watchesRestTimerCompletion()
        .onAppear {
            UIApplication.shared.enableTapToDismissKeyboard()
            ExerciseData.seedIfNeeded(in: modelContext)
            WorkoutSessionManager.shared.reconcileOrphanedActiveWorkouts(in: modelContext)
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
