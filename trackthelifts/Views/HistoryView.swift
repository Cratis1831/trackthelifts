//
//  HistoryView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Workout> { workout in
            workout.completedAt != nil && !workout.isDeleted
        },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    private let sessionManager = WorkoutSessionManager.shared

    @State private var resumingWorkout: Workout?
    @State private var isCreateWorkoutPresented = false
    @State private var showActiveWorkoutAlert = false
    @State private var workoutToNameTemplate: Workout?
    @State private var templateName: String = ""
    @State private var workoutToDelete: Workout?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if completedWorkouts.isEmpty {
                    EmptyStateView(
                        systemImage: "clock.badge.checkmark",
                        title: "No Completed Workouts",
                        message: "Your workout history will appear here once you complete your first workout."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(completedWorkouts) { workout in
                                NavigationLink(value: workout) {
                                    WorkoutHistoryCard(
                                        workout: workout,
                                        onSaveAsTemplate: {
                                            templateName = workout.title
                                            workoutToNameTemplate = workout
                                        },
                                        onDuplicate: { duplicateWorkout(workout) },
                                        onDelete: {
                                            workoutToDelete = workout
                                            showingDeleteConfirmation = true
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
        .fullScreenCover(isPresented: $isCreateWorkoutPresented, onDismiss: {
            resumingWorkout = nil
        }) {
            CreateWorkoutView(existingWorkout: resumingWorkout)
        }
        .alert("Workout In Progress", isPresented: $showActiveWorkoutAlert) {
            Button("OK") { }
        } message: {
            Text("Finish or discard your current workout before starting another one.")
        }
        .alert("Save as Template", isPresented: Binding(
            get: { workoutToNameTemplate != nil },
            set: { if !$0 { workoutToNameTemplate = nil } }
        )) {
            TextField("Template Name", text: $templateName)
            Button("Save") {
                if let workout = workoutToNameTemplate {
                    _ = TemplateService.makeTemplate(from: workout, name: templateName, in: modelContext)
                }
                workoutToNameTemplate = nil
            }
            Button("Cancel", role: .cancel) {
                workoutToNameTemplate = nil
            }
        } message: {
            Text("This will create a routine you can start again later.")
        }
        .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    modelContext.delete(workout)
                    try? modelContext.save()
                    Haptics.impact(.medium)
                }
                workoutToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                workoutToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this workout? This cannot be undone.")
        }
    }

    private func duplicateWorkout(_ workout: Workout) {
        guard !sessionManager.hasActiveWorkout(in: modelContext) else {
            showActiveWorkoutAlert = true
            return
        }
        let newWorkout = workout.duplicate(in: modelContext)
        resumingWorkout = newWorkout
        sessionManager.startWorkout(workoutID: newWorkout.id)
        isCreateWorkoutPresented = true
    }
}

struct WorkoutHistoryCard: View {
    let workout: Workout
    var onSaveAsTemplate: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    private var exerciseGroups: [(String, [ExerciseSet])] {
        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        return grouped.sorted { $0.key < $1.key }
    }
    
    private var totalSets: Int {
        workout.exerciseSets.count
    }
    
    private var completedSets: Int {
        workout.exerciseSets.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let completedAt = workout.completedAt {
                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    }
                }
                
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completedSets)/\(totalSets) sets")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appAccent)

                    Text("\(exerciseGroups.count) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                }

                Menu {
                    cardMenuActions
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.appAccent)
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            
            // Exercise Summary
            if !exerciseGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exerciseGroups.prefix(3)), id: \.0) { exerciseName, sets in
                        HStack {
                            Text("• \(exerciseName)")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.76, green: 0.76, blue: 0.78))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(sets.count) set\(sets.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        }
                    }
                    
                    if exerciseGroups.count > 3 {
                        Text("and \(exerciseGroups.count - 3) more...")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            .padding(.top, 2)
                    }
                }
            }
            
            // Workout Notes (if any)
            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.66, green: 0.66, blue: 0.68))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
        )
        .contextMenu {
            cardMenuActions
        }
    }

    @ViewBuilder
    private var cardMenuActions: some View {
        Button {
            onSaveAsTemplate()
        } label: {
            Label("Save as Template", systemImage: "square.and.arrow.down.on.square")
        }
        Button {
            onDuplicate()
        } label: {
            Label("Duplicate Workout", systemImage: "repeat")
        }
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete Workout", systemImage: "trash")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [
            Workout.self, Exercise.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
