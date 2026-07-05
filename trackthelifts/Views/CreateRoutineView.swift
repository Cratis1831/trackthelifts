//
//  CreateRoutineView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

/// Lets the user build a new routine (template) from scratch: name it, add exercises, and pick
/// a target number of sets for each.
struct CreateRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingTemplate: WorkoutTemplate? = nil

    @State private var name: String = ""
    @State private var entries: [DraftExercise] = []
    @State private var showExercisePicker = false

    struct DraftExercise: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var targetSets: Int = 3
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !entries.isEmpty
    }

    private var navigationTitle: String {
        existingTemplate == nil ? "New Routine" : "Edit Routine"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Routine Name", text: $name)
                        .font(.title.bold())
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    if entries.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 44))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            Text("Add exercises to build this routine.")
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        List {
                            ForEach($entries) { $entry in
                                HStack {
                                    Text(entry.exercise.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Stepper(
                                        "\(entry.targetSets) set\(entry.targetSets == 1 ? "" : "s")",
                                        value: $entry.targetSets,
                                        in: 1...10
                                    )
                                    .fixedSize()
                                    .foregroundColor(Color(red: 0.76, green: 0.76, blue: 0.78))
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        entries.removeAll { $0.id == entry.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                            .onMove { source, destination in
                                entries.move(fromOffsets: source, toOffset: destination)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                    }
                    .buttonStyle(WorkoutActionButtonStyle(tint: .orange, prominence: .filled))
                    .padding(.horizontal, 10)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !entries.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoutine() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExerciseListView(chooseExercise: true, onExerciseSelected: { exercise in
                    if !entries.contains(where: { $0.exercise.id == exercise.id }) {
                        entries.append(DraftExercise(exercise: exercise))
                    }
                    showExercisePicker = false
                })
            }
            .onAppear {
                if let existingTemplate, entries.isEmpty {
                    name = existingTemplate.name
                    entries = existingTemplate.templateExercises
                        .sorted { $0.order < $1.order }
                        .map { DraftExercise(exercise: $0.exercise, targetSets: $0.targetSets) }
                }
            }
        }
    }

    private func saveRoutine() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let template: WorkoutTemplate

        if let existingTemplate {
            template = existingTemplate
            template.name = trimmedName
            template.updatedAt = .now

            // Remove template exercises for anything no longer in `entries`.
            let entryExerciseIDs = Set(entries.map { $0.exercise.id })
            for stale in template.templateExercises where !entryExerciseIDs.contains(stale.exercise.id) {
                modelContext.delete(stale)
            }
            template.templateExercises.removeAll { !entryExerciseIDs.contains($0.exercise.id) }
        } else {
            template = WorkoutTemplate(name: trimmedName)
            modelContext.insert(template)
        }

        for (index, entry) in entries.enumerated() {
            if let match = template.templateExercises.first(where: { $0.exercise.id == entry.exercise.id }) {
                match.order = index
                match.targetSets = entry.targetSets
            } else {
                let templateExercise = WorkoutTemplateExercise(
                    order: index,
                    targetSets: entry.targetSets,
                    targetReps: 8,
                    targetWeight: 0,
                    template: template,
                    exercise: entry.exercise
                )
                modelContext.insert(templateExercise)
                template.templateExercises.append(templateExercise)
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save routine: \(error)")
        }
    }
}

#Preview {
    CreateRoutineView()
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
