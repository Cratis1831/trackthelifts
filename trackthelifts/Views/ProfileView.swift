//
//  ProfileView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        ProgressDashboardView()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
