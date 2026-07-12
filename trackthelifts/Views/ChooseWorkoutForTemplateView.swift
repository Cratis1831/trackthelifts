//
//  ChooseWorkoutForTemplateView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

/// Lets the user pick a completed workout to save as a routine (template).
struct ChooseWorkoutForTemplateView: View {
    @Query(
        filter: #Predicate<Workout> { $0.completedAt != nil && !$0.isDeleted },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]

    @Environment(\.dismiss) private var dismiss
    var onSelect: (Workout) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                if completedWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundColor(Color.appTextSecondary)

                        Text("No Completed Workouts")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.appTextPrimary)

                        Text("Complete a workout first, then you can save it as a routine here.")
                            .font(.system(size: 16))
                            .foregroundColor(Color.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(completedWorkouts) { workout in
                            Button {
                                onSelect(workout)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.appTextPrimary)

                                    if let completedAt = workout.completedAt {
                                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.appSurface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Choose Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ChooseWorkoutForTemplateView(onSelect: { _ in })
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
