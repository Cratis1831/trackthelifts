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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Routine Name", text: $name)
                        .font(.system(size: 18, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
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
                                .listRowBackground(Color(red: 0.11, green: 0.11, blue: 0.12))
                            }
                            .onDelete { indexSet in
                                entries.remove(atOffsets: indexSet)
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
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        }
    }

    private func saveRoutine() {
        let template = WorkoutTemplate(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(template)

        for (index, entry) in entries.enumerated() {
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
