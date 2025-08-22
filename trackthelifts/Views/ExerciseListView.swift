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
    @Query(sort: \Bodypart.name) private var bodyparts: [Bodypart]
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if filteredExercises.isEmpty && exercises.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        
                        Text("No Exercises Found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Tap 'Seed Exercises' to add default exercises")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button("Seed Exercises") {
                            forceSeedExercises()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else if filteredExercises.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        
                        Text("No Results")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Try a different search term")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    }
                } else {
                    VStack(spacing: 0) {
                        if !chooseExercise {
                            searchBar
                        }
                        
                        List {
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
                                        .foregroundColor(.orange)
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
            .toolbar {
                if chooseExercise {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.orange)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            showingExerciseDetail = true
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
        }
        .onAppear {
            print("🔍 ExerciseListView onAppear - Current exercise count: \(exercises.count)")
            loadExercises()
            if exercises.isEmpty && manualExercises.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    seedDefaultExercises()
                }
            }
        }
        .id(refreshTrigger)
        .sheet(isPresented: $showingExerciseDetail, onDismiss: {
            exerciseToEdit = nil
        }) {
            ExerciseDetailView(exercise: exerciseToEdit)
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
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            
            TextField("Search exercises...", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
                // Circular avatar with initials
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(exerciseInitials(exercise.name))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
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
            .padding(.vertical, 8)
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
            } catch {
                deleteErrorMessage = "Failed to delete exercise: \(error.localizedDescription)"
                showingDeleteError = true
            }
        } else {
            do {
                modelContext.delete(exercise)
                try modelContext.save()
                exerciseToDelete = nil
            } catch {
                deleteErrorMessage = "Failed to delete exercise: \(error.localizedDescription)"
                showingDeleteError = true
            }
        }
    }
    
    private func seedDefaultExercises() {
        print("🌱 Starting seedDefaultExercises - Current count: \(exercises.count)")
        
        // First, seed bodyparts if they don't exist
        seedBodyparts()
        
        // Then seed exercises with bodyparts
        for exerciseInfo in ExerciseData.defaultExercises {
            let bodypart = bodyparts.first { $0.name == exerciseInfo.bodypart }
            let exercise = Exercise(name: exerciseInfo.name, bodypart: bodypart)
            modelContext.insert(exercise)
            print("➕ Inserted exercise: \(exerciseInfo.name) (\(exerciseInfo.bodypart))")
        }

        do {
            try modelContext.save()
            print("✅ Successfully seeded \(ExerciseData.defaultExercises.count) default exercises")
            
            // Force UI refresh and reload exercises
            DispatchQueue.main.async {
                loadExercises()
                refreshTrigger.toggle()
            }
        } catch {
            print("❌ Failed to save default exercises: \(error)")
        }
    }
    
    private func seedBodyparts() {
        for bodypartName in ExerciseData.defaultBodyparts {
            if !bodyparts.contains(where: { $0.name == bodypartName }) {
                let bodypart = Bodypart(name: bodypartName)
                modelContext.insert(bodypart)
                print("➕ Inserted bodypart: \(bodypartName)")
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to seed bodyparts: \(error)")
        }
    }
    
    private func forceSeedExercises() {
        print("🚀 Force seeding exercises...")
        seedDefaultExercises()
    }
    
    private func loadExercises() {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.name)]
        )
        
        do {
            let fetchedExercises = try modelContext.fetch(descriptor)
            manualExercises = fetchedExercises
            print("🔄 Loaded \(fetchedExercises.count) exercises manually")
        } catch {
            print("❌ Failed to manually load exercises: \(error)")
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
