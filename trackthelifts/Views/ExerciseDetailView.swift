//
//  ExerciseDetailView.swift
//  TrackTheLifts
//
//  Created by Claude on 2025-08-22.
//

import SwiftUI
import SwiftData


struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bodypart.name) private var bodyparts: [Bodypart]
    
    let exercise: Exercise?
    var onSave: ((Exercise) -> Void)? = nil
    @State private var exerciseName: String = ""
    @State private var selectedBodypart: Bodypart?
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var isNameFieldFocused: Bool

    init(exercise: Exercise? = nil, onSave: ((Exercise) -> Void)? = nil) {
        self.exercise = exercise
        self.onSave = onSave
    }
    
    var isEditing: Bool {
        exercise != nil
    }
    
    var title: String {
        isEditing ? "Edit Exercise" : "Add Exercise"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exercise Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        TextField("Enter exercise name", text: $exerciseName)
                            .font(.system(size: 16))
                            .textFieldStyle(.plain)
                            .focused($isNameFieldFocused)
                            .padding(12)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body Part")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Menu {
                            Button("None") {
                                selectedBodypart = nil
                            }

                            ForEach(bodyparts) { bodypart in
                                Button(bodypart.name) {
                                    selectedBodypart = bodypart
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedBodypart?.name ?? "Select body part")
                                    .font(.system(size: 16))
                                    .foregroundColor(selectedBodypart == nil ? Color(red: 0.56, green: 0.56, blue: 0.58) : .white)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            }
                            .padding(12)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .foregroundColor(.orange)
                    .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            setupInitialData()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupInitialData() {
        if let exercise = exercise {
            exerciseName = exercise.name
            selectedBodypart = exercise.bodypart
        } else {
            isNameFieldFocused = true
        }
    }
    
    private func saveExercise() {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Exercise name cannot be empty"
            showingError = true
            return
        }
        
        let savedExercise: Exercise
        if let existingExercise = exercise {
            existingExercise.name = trimmedName
            existingExercise.bodypart = selectedBodypart
            existingExercise.updatedAt = .now
            savedExercise = existingExercise
        } else {
            let newExercise = Exercise(
                name: trimmedName,
                bodypart: selectedBodypart
            )
            modelContext.insert(newExercise)
            savedExercise = newExercise
        }

        do {
            try modelContext.save()
            onSave?(savedExercise)
            dismiss()
        } catch {
            errorMessage = "Failed to save exercise: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Exercise.self, Bodypart.self,
        configurations: config
    )
    
    let chest = Bodypart(name: "Chest")
    let back = Bodypart(name: "Back")
    container.mainContext.insert(chest)
    container.mainContext.insert(back)
    
    return ExerciseDetailView()
        .modelContainer(container)
}