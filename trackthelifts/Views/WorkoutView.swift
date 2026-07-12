//
//  WorkoutView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Query(sort: \Workout.updatedAt, order: .reverse) private var workouts: [Workout]
    @Query private var templates: [WorkoutTemplate]
    @Environment(\.modelContext) private var modelContext
    @State private var isCreateWorkoutPresented: Bool = false
    @State private var isCreateRoutinePresented: Bool = false
    @State private var isChooseWorkoutForRoutinePresented: Bool = false
    @State private var templateToEdit: WorkoutTemplate?
    @State private var showActiveWorkoutAlert = false
    @State private var workoutToNameAsTemplate: Workout?
    @State private var newTemplateName: String = ""
    @State private var sortBy: SortOption = .name
    @State private var resumingWorkout: Workout? = nil

    private let sessionManager = WorkoutSessionManager.shared

    private var activeWorkout: Workout? {
        sessionManager.getActiveWorkout(from: modelContext)
    }

    private var sortedTemplates: [WorkoutTemplate] {
        switch sortBy {
        case .name:
            return templates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            return templates.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case recent = "Recent"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()
                PrecisionGridBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // Resume Workout Banner
                        if let activeWorkout = activeWorkout, sessionManager.isWorkoutMinimized {
                            ResumeWorkoutBanner(workout: activeWorkout) {
                                resumingWorkout = activeWorkout
                                sessionManager.resumeWorkout()
                                isCreateWorkoutPresented = true
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        
                        // Templates Section
                        VStack(alignment: .leading, spacing: 20) {
                            // Templates Header
                            HStack {
                                Text("Routines")
                                    .font(.appSectionTitle)
                                    .foregroundColor(.appTextPrimary)
                                
                                Spacer()
                                
                                Menu {
                                    Button {
                                        isCreateRoutinePresented = true
                                    } label: {
                                        Label("New Blank Routine", systemImage: "square.and.pencil")
                                    }
                                    Button {
                                        isChooseWorkoutForRoutinePresented = true
                                    } label: {
                                        Label("From a Past Workout", systemImage: "clock.arrow.circlepath")
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16))
                                        Text("Add Routine")
                                            .font(.system(size: 16))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: AppDesign.compactRadius))
                                .tint(.appTextSecondary)
                            }

                            // My Templates Header
                            HStack {
                                Text("My Routines (\(templates.count))")
                                    .font(.appUtility)
                                    .tracking(0.6)
                                    .textCase(.uppercase)
                                    .foregroundColor(.appTextPrimary)

                                Spacer()

                                Menu {
                                    Button(action: { sortBy = .name }) {
                                        Label("Sort by Name", systemImage: "textformat")
                                    }

                                    Button(action: { sortBy = .recent }) {
                                        Label("Sort by Recent", systemImage: "clock")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.appAccent)
                                        .font(.system(size: 20))
                                }
                            }

                            // Template Cards
                            if !templates.isEmpty {
                                LazyVStack(spacing: 15) {
                                    ForEach(sortedTemplates) { template in
                                        TemplateCard(template: template, onTap: {
                                            startWorkout(from: template)
                                        }, onEdit: {
                                            templateToEdit = template
                                        })
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 100) // Space for floating action button
                }

                // Empty state — centered in the screen to match the
                // History and Progress tabs.
                if templates.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle",
                        title: "No Routines Yet",
                        message: "Save a completed workout as a routine, or add a new one, to see it here."
                    )
                }

                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if sessionManager.isWorkoutMinimized {
                                resumingWorkout = activeWorkout
                                sessionManager.resumeWorkout()
                            } else {
                                resumingWorkout = nil
                            }
                            isCreateWorkoutPresented = true
                        }) {
                            Image(systemName: sessionManager.isWorkoutMinimized ? "play.fill" : "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(sessionManager.isWorkoutMinimized ? .appTextPrimary : .onAppAction)
                                .frame(width: 56, height: 56)
                                .background(sessionManager.isWorkoutMinimized ? Color.green : Color.appAction)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 1))
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Workouts")
        }
        .fullScreenCover(isPresented: $isCreateWorkoutPresented, onDismiss: {
            resumingWorkout = nil
        }) {
            CreateWorkoutView(existingWorkout: resumingWorkout)
        }
        .sheet(isPresented: $isCreateRoutinePresented) {
            CreateRoutineView()
        }
        .sheet(item: $templateToEdit) { template in
            CreateRoutineView(existingTemplate: template)
        }
        .sheet(isPresented: $isChooseWorkoutForRoutinePresented) {
            ChooseWorkoutForTemplateView { workout in
                newTemplateName = workout.title
                workoutToNameAsTemplate = workout
            }
        }
        .alert("Save as Routine", isPresented: Binding(
            get: { workoutToNameAsTemplate != nil },
            set: { if !$0 { workoutToNameAsTemplate = nil } }
        )) {
            TextField("Routine Name", text: $newTemplateName)
            Button("Save") {
                if let workout = workoutToNameAsTemplate {
                    _ = TemplateService.makeTemplate(from: workout, name: newTemplateName, in: modelContext)
                }
                workoutToNameAsTemplate = nil
            }
            Button("Cancel", role: .cancel) {
                workoutToNameAsTemplate = nil
            }
        } message: {
            Text("This will create a routine you can start again later.")
        }
        .alert("Workout In Progress", isPresented: $showActiveWorkoutAlert) {
            Button("OK") { }
        } message: {
            Text("Finish or discard your current workout before starting another one.")
        }
    }

    private func startWorkout(from template: WorkoutTemplate) {
        guard !sessionManager.hasActiveWorkout(in: modelContext) else {
            showActiveWorkoutAlert = true
            return
        }
        let workout = template.instantiateWorkout(in: modelContext)
        resumingWorkout = workout
        sessionManager.startWorkout(workoutID: workout.id)
        isCreateWorkoutPresented = true
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onTap: () -> Void
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var exercisesSummary: String {
        template.templateExercises
            .sorted { $0.order < $1.order }
            .map { $0.exercise.name }
            .joined(separator: ", ")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    Menu {
                        Button("Edit Template") {
                            onEdit()
                        }
                        Button("Duplicate Template") {
                            _ = template.duplicateTemplate(in: modelContext)
                        }
                        Divider()
                        Button("Delete Template", role: .destructive) {
                            modelContext.delete(template)
                            try? modelContext.save()
                            Haptics.impact(.medium)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.appAccent)
                            .font(.system(size: 16))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }

                Text(exercisesSummary)
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(Color.appSurface)
            .cornerRadius(AppDesign.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cardRadius)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ResumeWorkoutBanner: View {
    let workout: Workout
    let onResume: () -> Void
    
    private var completedSets: Int {
        workout.exerciseSets.filter { $0.isCompleted }.count
    }
    
    private var totalSets: Int {
        workout.exerciseSets.count
    }
    
    private var uniqueExercises: Int {
        Set(workout.exerciseSets.map { $0.exercise.name }).count
    }
    
    var body: some View {
        Button(action: onResume) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        
                        Text("Resume Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Text(workout.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                    
                    Text("\(completedSets)/\(totalSets) sets • \(uniqueExercises) exercises")
                        .font(.appUtility)
                        .foregroundColor(Color.appTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.appTextSecondary)
                    .font(.system(size: 14))
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .appCard(padding: 4)
    }
}

#Preview {
    WorkoutView()
        .modelContainer(for: [
            Workout.self, Exercise.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
