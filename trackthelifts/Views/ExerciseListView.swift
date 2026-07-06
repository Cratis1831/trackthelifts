//
//  ExercisesView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftData
import SwiftUI

struct ExerciseListView: View {
    var chooseExercise: Bool = false
    var onExerciseSelected: ((Exercise) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var exerciseSets: [ExerciseSet]
    @State private var refreshTrigger = false
    @State private var manualExercises: [Exercise] = []
    @State private var searchText: String = ""
    @State private var showingExerciseDetail: Bool = false
    @State private var exerciseToEdit: Exercise?
    @State private var showingDeleteConfirmation: Bool = false
    @State private var exerciseToDelete: Exercise?
    @State private var deleteErrorMessage: String?
    @State private var showingDeleteError: Bool = false
    
    private var filteredExercises: [Exercise] {
        let allExercises = exercises.isEmpty ? manualExercises : exercises
        if searchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                (exercise.bodypart?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            exercise.bodypart?.name ?? "No Body Part"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    private var recentExercises: [Exercise] {
        guard chooseExercise, searchText.isEmpty else { return [] }
        return RecentExercisesService.recentExercises(in: modelContext)
    }

    var body: some View {
        content
            .onAppear {
                loadExercises()
                if exercises.isEmpty && manualExercises.isEmpty {
                    ExerciseData.seedIfNeeded(in: modelContext)
                    loadExercises()
                    refreshTrigger.toggle()
                }
            }
            .id(refreshTrigger)
            .sheet(isPresented: $showingExerciseDetail, onDismiss: {
                exerciseToEdit = nil
            }) {
                ExerciseDetailView(exercise: exerciseToEdit, initialName: exerciseToEdit == nil ? searchText : "", onSave: { savedExercise in
                    if chooseExercise, let onExerciseSelected {
                        onExerciseSelected(savedExercise)
                        dismiss()
                    }
                })
            }
            .alert("Delete Exercise", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    confirmDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let exercise = exerciseToDelete {
                    let usageCount = exerciseSets.filter { $0.exercise.id == exercise.id }.count
                    if usageCount > 0 {
                        Text("This exercise is used in \(usageCount) workout set(s). Deleting it will affect your workout history.")
                    } else {
                        Text("Are you sure you want to delete '\(exercise.name)'?")
                    }
                }
            }
            .alert("Cannot Delete", isPresented: $showingDeleteError) {
                Button("OK") { }
            } message: {
                Text(deleteErrorMessage ?? "An error occurred")
            }
    }

    private var content: some View {
        navigationContent
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: "Search exercises..."
            )
            .searchToolbarBehavior(.minimize)
    }

    private var navigationContent: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if filteredExercises.isEmpty && exercises.isEmpty {
                    EmptyStateView(
                        systemImage: "dumbbell",
                        title: "No Exercises",
                        message: "Your exercise library is empty. Restore the built-in exercises to get started.",
                        actionTitle: "Restore Default Exercises",
                        action: { restoreDefaultExercises() }
                    )
                } else if filteredExercises.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No Results",
                        message: "Try a different search term",
                        actionTitle: "Add New Exercise",
                        action: {
                            exerciseToEdit = nil
                            showingExerciseDetail = true
                        }
                    )
                } else {
                    VStack(spacing: 0) {
                        List {
                            if !recentExercises.isEmpty {
                                Section {
                                    ForEach(Array(recentExercises.enumerated()), id: \.element.id) { index, exercise in
                                        exerciseRow(exercise,
                                                  isFirst: index == 0,
                                                  isLast: index == recentExercises.count - 1)
                                            .listRowSeparator(index == recentExercises.count - 1 ? .hidden : .visible)
                                    }
                                } header: {
                                    Text("Recent")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.appAccent)
                                        .textCase(nil)
                                }
                                .listSectionSeparator(.hidden)
                            }
                            ForEach(groupedExercises, id: \.0) { bodypartName, bodypartExercises in
                                Section {
                                    ForEach(Array(bodypartExercises.enumerated()), id: \.element.id) { index, exercise in
                                        exerciseRow(exercise, 
                                                  isFirst: index == 0,
                                                  isLast: index == bodypartExercises.count - 1)
                                            .listRowSeparator(index == bodypartExercises.count - 1 ? .hidden : .visible)
                                    }
                                    .onDelete { indexSet in
                                        deleteExercises(from: bodypartExercises, at: indexSet)
                                    }
                                } header: {
                                    Text(bodypartName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.appAccent)
                                        .textCase(nil)
                                }
                                .listSectionSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if chooseExercise {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.appAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingExerciseDetail = true
                    }
                    .foregroundColor(.appAccent)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise, isFirst: Bool = false, isLast: Bool = false) -> some View {
        Button {
            if chooseExercise, let onExerciseSelected = onExerciseSelected {
                onExerciseSelected(exercise)
                dismiss()
            } else {
                exerciseToEdit = exercise
                showingExerciseDetail = true
            }
        } label: {
            HStack(spacing: 12) {
                // Rounded-square tile with initials, colored per body part.
                IconTile(color: BodypartPalette.color(for: exercise.bodypart?.name), size: 34) {
                    Text(exerciseInitials(exercise.name))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    if let bodypart = exercise.bodypart {
                        Text(bodypart.name)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    }
                }

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }
            .padding(.vertical, 4)
        }
            .listRowBackground(
            UnevenRoundedRectangle(
                topLeadingRadius: isFirst ? 10 : 0,
                bottomLeadingRadius: isLast ? 10 : 0,
                bottomTrailingRadius: isLast ? 10 : 0,
                topTrailingRadius: isFirst ? 10 : 0
            )
            .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
        )
        // Inset the row separator so it starts at the text, not under the tile (like the reference).
        .alignmentGuide(.listRowSeparatorLeading) { _ in 46 }
    }
    
    private func deleteExercises(from exercises: [Exercise], at indexSet: IndexSet) {
        for index in indexSet {
            let exercise = exercises[index]
            exerciseToDelete = exercise
            showingDeleteConfirmation = true
            break
        }
    }
    
    private func exerciseInitials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let firstWord = words.first {
            return String(firstWord.prefix(2)).uppercased()
        }
        return "EX"
    }
    
    private func confirmDelete() {
        guard let exercise = exerciseToDelete else { return }
        
        let usageCount = exerciseSets.filter { $0.exercise.id == exercise.id }.count
        
        if usageCount > 0 {
            do {
                modelContext.delete(exercise)
                try modelContext.save()
                exerciseToDelete = nil
                Haptics.impact(.medium)
            } catch {
                deleteErrorMessage = "Failed to delete exercise: \(error.localizedDescription)"
                showingDeleteError = true
            }
        } else {
            do {
                modelContext.delete(exercise)
                try modelContext.save()
                exerciseToDelete = nil
                Haptics.impact(.medium)
            } catch {
                deleteErrorMessage = "Failed to delete exercise: \(error.localizedDescription)"
                showingDeleteError = true
            }
        }
    }
    
    /// Manual recovery action for the empty state (e.g. if every exercise was deleted, or the
    /// automatic launch-time seed didn't run yet). Seeding itself normally happens once,
    /// automatically, from `ContentView`.
    private func restoreDefaultExercises() {
        ExerciseData.seedIfNeeded(in: modelContext)
        loadExercises()
        refreshTrigger.toggle()
    }

    private func loadExercises() {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.name)]
        )

        do {
            manualExercises = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to manually load exercises: \(error)")
        }
    }

    func addExercise(from template: Exercise, to workout: Workout) {
        let newExerciseSet = ExerciseSet(
            weight: 0.0,
            reps: 0,
            order: workout.exerciseSets.count,
            exercise: template,
            workout: workout
        )
        workout.exerciseSets.append(newExerciseSet)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Exercise.self, ExerciseSet.self, Workout.self, Bodypart.self,
        configurations: config
    )

    let quadriceps = Bodypart(name: "Quadriceps")
    let chest = Bodypart(name: "Chest")
    let back = Bodypart(name: "Back")
    let biceps = Bodypart(name: "Biceps")
    
    container.mainContext.insert(quadriceps)
    container.mainContext.insert(chest)
    container.mainContext.insert(back)
    container.mainContext.insert(biceps)

    let mockExercises = [
        Exercise(name: "Barbell Bench Press", bodypart: chest),
        Exercise(name: "Incline Dumbbell Press", bodypart: chest),
        Exercise(name: "Squat", bodypart: quadriceps),
        Exercise(name: "Deadlift", bodypart: back),
        Exercise(name: "Barbell Curl", bodypart: biceps),
    ]

    for ex in mockExercises {
        container.mainContext.insert(ex)
    }

    return ExerciseListView()
        .modelContainer(container)
}
