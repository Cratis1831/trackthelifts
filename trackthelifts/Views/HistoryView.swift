//
//  HistoryView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Query(
        filter: #Predicate<Workout> { workout in
            workout.completedAt != nil && !workout.isDeleted
        },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]
    @Query private var templates: [WorkoutTemplate]

    @Environment(\.modelContext) private var modelContext
    private let sessionManager = WorkoutSessionManager.shared

    @State private var resumingWorkout: Workout?
    @State private var isCreateWorkoutPresented = false
    @State private var showActiveWorkoutAlert = false
    @State private var workoutToNameTemplate: Workout?
    @State private var templateName: String = ""
    @State private var workoutToDelete: Workout?
    @State private var showingDeleteConfirmation = false
    @State private var selectedProFeature: ProFeature?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()
                PrecisionGridBackground()
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
                                            beginSavingRoutine(from: workout)
                                        },
                                        onRepeat: { repeatWorkout(workout) },
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
        .alert("Save as Routine", isPresented: Binding(
            get: { workoutToNameTemplate != nil },
            set: { if !$0 { workoutToNameTemplate = nil } }
        )) {
            TextField("Template Name", text: $templateName)
            Button("Save") {
                if let workout = workoutToNameTemplate {
                    if let blockedFeature = blockedFeatureForNewRoutine(from: workout) {
                        selectedProFeature = blockedFeature
                    } else {
                        do {
                            _ = try TemplateService.makeTemplate(from: workout, name: templateName, in: modelContext)
                            AnalyticsService.track(.routineSaved(source: .pastWorkout))
                        } catch {
                            print("Failed to save routine from workout: \(error)")
                        }
                    }
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
        .proPaywall(feature: $selectedProFeature)
    }

    private func repeatWorkout(_ workout: Workout) {
        guard !sessionManager.hasActiveWorkout(in: modelContext) else {
            showActiveWorkoutAlert = true
            return
        }
        do {
            let newWorkout = try workout.duplicate(in: modelContext)
            resumingWorkout = newWorkout
            sessionManager.startWorkout(workoutID: newWorkout.id)
            AnalyticsService.track(.workoutStarted(source: .repeatWorkout))
            isCreateWorkoutPresented = true
        } catch {
            print("Failed to repeat workout: \(error)")
        }
    }

    private func beginSavingRoutine(from workout: Workout) {
        if let blockedFeature = blockedFeatureForNewRoutine(from: workout) {
            selectedProFeature = blockedFeature
            return
        }
        templateName = workout.title
        workoutToNameTemplate = workout
    }

    private func blockedFeatureForNewRoutine(from workout: Workout) -> ProFeature? {
        guard SubscriptionAccessPolicy.canCreateRoutine(
            existingCount: templates.count,
            tier: revenueCatService.currentTier
        ) else {
            return .unlimitedRoutines
        }
        if workout.containsSupersets && !revenueCatService.canAccess(.supersets) {
            return .supersets
        }
        return nil
    }
}

struct WorkoutHistoryCard: View {
    let workout: Workout
    var onSaveAsTemplate: () -> Void
    var onRepeat: () -> Void
    var onDelete: () -> Void

    private var exerciseGroups: [(String, [ExerciseSet])] {
        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        return grouped.sorted { lhs, rhs in
            let lhsOrder = lhs.value.map(\.exerciseOrder).min() ?? .max
            let rhsOrder = rhs.value.map(\.exerciseOrder).min() ?? .max
            return lhsOrder == rhsOrder ? lhs.key < rhs.key : lhsOrder < rhsOrder
        }
    }
    
    private var totalSets: Int {
        workout.exerciseSets.count
    }
    
    private var completedSets: Int {
        workout.exerciseSets.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Grouping walks every set of the workout; compute it once per render instead of
            // once per access (the header, summary list, and overflow line all read it).
            let groups = exerciseGroups
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                    
                    if let completedAt = workout.completedAt {
                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.appUtility)
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completedSets)/\(totalSets) sets")
                        .font(.appUtility)
                        .foregroundColor(.appAccent)

                    Text("\(groups.count) exercises")
                        .font(.appUtility)
                        .foregroundColor(Color.appTextSecondary)
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
            if !groups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(groups.prefix(3)), id: \.0) { exerciseName, sets in
                        HStack {
                            if let position = supersetPosition(for: exerciseName, in: groups) {
                                Text("A\(position)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.onAppAccent)
                                    .frame(width: 20, height: 20)
                                    .background(Color.appAccent)
                                    .clipShape(Circle())
                            } else {
                                Text("•")
                                    .foregroundColor(Color.appTextSecondary)
                            }

                            Text(exerciseName)
                                .font(.system(size: 14))
                                .foregroundColor(Color.appTextPrimary.opacity(0.78))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(sets.count) set\(sets.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    
                    if groups.count > 3 {
                        Text("and \(groups.count - 3) more...")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.top, 2)
                    }
                }
            }
            
            // Workout Notes (if any)
            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(AppDesign.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cardRadius)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .contextMenu {
            cardMenuActions
        }
    }

    private func supersetPosition(
        for exerciseName: String,
        in groups: [(String, [ExerciseSet])]
    ) -> Int? {
        guard let index = groups.firstIndex(where: { $0.0 == exerciseName }),
              let groupID = groups[index].1.first?.supersetGroupID else { return nil }
        let members = groups.indices.filter { groups[$0].1.first?.supersetGroupID == groupID }
        guard let memberIndex = members.firstIndex(of: index) else { return nil }
        return memberIndex + 1
    }

    @ViewBuilder
    private var cardMenuActions: some View {
        Button {
            onSaveAsTemplate()
        } label: {
            Label("Save as Routine", systemImage: "square.and.arrow.down.on.square")
        }
        Button {
            onRepeat()
        } label: {
            Label("Repeat Workout", systemImage: "repeat")
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
        .environmentObject(RevenueCatService.shared)
        .modelContainer(for: [
            Workout.self, Exercise.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
