//
//  CreateRoutineView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

/// Lets the user build a new routine (template) from scratch: name it, add exercises, and pick
/// a target number of sets for each.
struct CreateRoutineView: View {
    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [WorkoutTemplate]

    var existingTemplate: WorkoutTemplate? = nil

    @State private var name: String = ""
    @State private var entries: [DraftExercise] = []
    @State private var showExercisePicker = false
    @State private var selectedProFeature: ProFeature?

    struct DraftExercise: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var targetSets: Int = 3
        var supersetGroupID: UUID?
    }

    private var entryBlocks: [[DraftExercise]] {
        var blocks: [[DraftExercise]] = []
        var index = 0
        while index < entries.count {
            let entry = entries[index]
            if let groupID = entry.supersetGroupID,
               index + 1 < entries.count,
               entries[index + 1].supersetGroupID == groupID {
                blocks.append([entry, entries[index + 1]])
                index += 2
            } else {
                blocks.append([entry])
                index += 1
            }
        }
        return blocks
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
                Color.appCanvas.ignoresSafeArea()

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
                                .foregroundColor(Color.appTextSecondary)
                            Text("Add exercises to build this routine.")
                                .font(.system(size: 15))
                                .foregroundColor(Color.appTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        List {
                            ForEach(entryBlocks, id: \.first!.id) { block in
                                VStack(spacing: 0) {
                                ForEach(block) { blockEntry in
                                    let entryIndex = entries.firstIndex(where: { $0.id == blockEntry.id })!
                                HStack(spacing: 10) {
                                    if let position = supersetPosition(for: blockEntry.id) {
                                        Text("A\(position)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(.onAppAccent)
                                            .frame(width: 24, height: 24)
                                            .background(Color.appAccent)
                                            .clipShape(Circle())
                                    }
                                    Text(blockEntry.exercise.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.appTextPrimary)

                                    Spacer()

                                    Stepper(
                                        "\(entries[entryIndex].targetSets) set\(entries[entryIndex].targetSets == 1 ? "" : "s")",
                                        value: $entries[entryIndex].targetSets,
                                        in: 1...10
                                    )
                                    .fixedSize()
                                    .foregroundColor(Color.appTextPrimary.opacity(0.78))

                                    Menu {
                                        supersetMenu(for: blockEntry.id)
                                    } label: {
                                        Image(systemName: blockEntry.supersetGroupID == nil ? "link" : "link.circle.fill")
                                            .foregroundColor(blockEntry.supersetGroupID == nil ? .appTextSecondary : .appAccent)
                                            .frame(width: 30, height: 30)
                                            .overlay(alignment: .topTrailing) {
                                                if blockEntry.supersetGroupID == nil && !revenueCatService.canAccess(.supersets) {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 7, weight: .bold))
                                                        .foregroundColor(.appTextSecondary)
                                                }
                                            }
                                    }
                                }
                                .padding(.vertical, 6)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        removeEntry(blockEntry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .tint(.red)
                                }
                                }
                                }
                                .overlay(alignment: .leading) {
                                    if block.count == 2 {
                                        Capsule()
                                            .fill(Color.appAccent)
                                            .frame(width: 3)
                                            .padding(.vertical, 5)
                                            .offset(x: -8)
                                    }
                                }
                            }
                            .onMove { source, destination in
                                var blocks = entryBlocks
                                blocks.move(fromOffsets: source, toOffset: destination)
                                entries = blocks.flatMap { $0 }
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
                    .buttonStyle(WorkoutActionButtonStyle(tint: .appAccent, prominence: .filled))
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
                        .map { DraftExercise(
                            exercise: $0.exercise,
                            targetSets: $0.targetSets,
                            supersetGroupID: $0.supersetGroupID
                        ) }
                }
            }
            .proPaywall(feature: $selectedProFeature)
        }
    }

    private func saveRoutine() {
        if existingTemplate == nil && !SubscriptionAccessPolicy.canCreateRoutine(
            existingCount: templates.count,
            tier: revenueCatService.currentTier
        ) {
            selectedProFeature = .unlimitedRoutines
            return
        }

        if entries.contains(where: { $0.supersetGroupID != nil })
            && !revenueCatService.canAccess(.supersets)
            && existingTemplate?.containsSupersets != true {
            selectedProFeature = .supersets
            return
        }

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
                match.supersetGroupID = entry.supersetGroupID
            } else {
                let templateExercise = WorkoutTemplateExercise(
                    order: index,
                    targetSets: entry.targetSets,
                    targetReps: 8,
                    targetWeight: 0,
                    supersetGroupID: entry.supersetGroupID,
                    template: template,
                    exercise: entry.exercise
                )
                modelContext.insert(templateExercise)
                template.templateExercises.append(templateExercise)
            }
        }

        do {
            try modelContext.save()
            AnalyticsService.track(.routineSaved(source: existingTemplate == nil ? .blank : .edit))
            dismiss()
        } catch {
            print("Failed to save routine: \(error)")
        }
    }

    private func supersetPosition(for entryID: UUID) -> Int? {
        guard let index = entries.firstIndex(where: { $0.id == entryID }),
              let groupID = entries[index].supersetGroupID else { return nil }
        let members = entries.indices.filter { entries[$0].supersetGroupID == groupID }
        guard let memberIndex = members.firstIndex(of: index) else { return nil }
        return memberIndex + 1
    }

    @ViewBuilder
    private func supersetMenu(for entryID: UUID) -> some View {
        if let index = entries.firstIndex(where: { $0.id == entryID }) {
            if entries[index].supersetGroupID != nil {
                Button("Remove Superset", role: .destructive) {
                    removeSuperset(containing: entryID)
                }
            } else {
                if index > 0, entries[index - 1].supersetGroupID == nil {
                    Button("Pair with \(entries[index - 1].exercise.name)") {
                        pairEntries(at: index - 1, and: index)
                    }
                }
                if index + 1 < entries.count, entries[index + 1].supersetGroupID == nil {
                    Button("Pair with \(entries[index + 1].exercise.name)") {
                        pairEntries(at: index, and: index + 1)
                    }
                }
                if (index == 0 || entries[index - 1].supersetGroupID != nil) &&
                    (index + 1 >= entries.count || entries[index + 1].supersetGroupID != nil) {
                    Text("No adjacent exercise available")
                }
            }
        }
    }

    private func pairEntries(at first: Int, and second: Int) {
        guard revenueCatService.canAccess(.supersets) else {
            selectedProFeature = .supersets
            return
        }
        guard entries.indices.contains(first), entries.indices.contains(second), abs(first - second) == 1,
              entries[first].supersetGroupID == nil, entries[second].supersetGroupID == nil else { return }
        let groupID = UUID()
        entries[first].supersetGroupID = groupID
        entries[second].supersetGroupID = groupID
        Haptics.selection()
    }

    private func removeSuperset(containing entryID: UUID) {
        guard let groupID = entries.first(where: { $0.id == entryID })?.supersetGroupID else { return }
        for index in entries.indices where entries[index].supersetGroupID == groupID {
            entries[index].supersetGroupID = nil
        }
        Haptics.selection()
    }

    private func removeEntry(_ entryID: UUID) {
        removeSuperset(containing: entryID)
        entries.removeAll { $0.id == entryID }
    }
}

#Preview {
    CreateRoutineView()
        .environmentObject(RevenueCatService.shared)
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
