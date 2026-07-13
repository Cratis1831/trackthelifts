//
//  WorkoutDetailView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

/// Editable detail view for a workout (typically a completed one, reached from History).
/// Lets the user rename the workout, edit set weight/reps/completion, add sets, and swipe to
/// remove an exercise (and all of its sets) entirely.
struct WorkoutDetailView: View {
    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext
    @State private var isReorderingExercises = false
    @State private var selectedProFeature: ProFeature?

    /// The workout's sets grouped per exercise (sets sorted by set order), in the persisted
    /// `exerciseOrder` (drag-reorderable by the user), falling back to earliest-created-set order
    /// for older data that predates `exerciseOrder`. `body` computes this once per render and
    /// passes the groups down, instead of re-grouping/re-sorting per exercise row.
    private var exerciseGroups: [(name: String, sets: [ExerciseSet])] {
        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        return grouped
            .map { (name: $0.key, sets: $0.value.sorted { $0.order < $1.order }) }
            .sorted { lhs, rhs in
                let order1 = lhs.sets.map(\.exerciseOrder).min() ?? Int.max
                let order2 = rhs.sets.map(\.exerciseOrder).min() ?? Int.max
                if order1 != order2 { return order1 < order2 }
                let earliest1 = lhs.sets.map(\.createdAt).min() ?? .distantFuture
                let earliest2 = rhs.sets.map(\.createdAt).min() ?? .distantFuture
                return earliest1 < earliest2
            }
    }

    private var exerciseBlocks: [[(name: String, sets: [ExerciseSet])]] {
        let groups = exerciseGroups
        var blocks: [[(name: String, sets: [ExerciseSet])]] = []
        var index = 0
        while index < groups.count {
            let group = groups[index]
            if let groupID = group.sets.first?.supersetGroupID,
               index + 1 < groups.count,
               groups[index + 1].sets.first?.supersetGroupID == groupID {
                blocks.append([group, groups[index + 1]])
                index += 2
            } else {
                blocks.append([group])
                index += 1
            }
        }
        return blocks
    }

    private func sets(for exerciseName: String) -> [ExerciseSet] {
        workout.exerciseSets
            .filter { $0.exercise.name == exerciseName }
            .sorted { $0.order < $1.order }
    }

    /// Reassigns sequential `exerciseOrder` values to every set after a drag-reorder. Only called
    /// from reorder mode, where the ForEach is a flat one-row-per-exercise list — the sole
    /// `.onMove` configuration List supports reliably (moving multi-row Sections crashes the
    /// List's index mapping).
    private func moveExerciseBlocks(from source: IndexSet, to destination: Int) {
        var blocks = exerciseBlocks
        guard source.allSatisfy({ $0 < blocks.count }), destination <= blocks.count else { return }
        blocks.move(fromOffsets: source, toOffset: destination)

        for (index, group) in blocks.flatMap({ $0 }).enumerated() {
            for set in group.sets {
                set.exerciseOrder = index
            }
        }

        persistWorkoutEdit()
        Haptics.impact(.light)
    }

    /// Exercise name row: long-press it (or tap its grip icon) to enter reorder mode.
    private func exerciseTitleRow(
        _ name: String,
        groups: [(name: String, sets: [ExerciseSet])],
        canReorder: Bool
    ) -> some View {
        HStack {
            if let position = supersetPosition(for: name, in: groups) {
                Text("A\(position)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.onAppAccent)
                    .frame(width: 24, height: 24)
                    .background(Color.appAccent)
                    .clipShape(Circle())
            }

            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            if workout.supersetID(for: name) != nil {
                Text("SUPERSET")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.appAccent)
            }

            if groups.count > 1 {
                Menu {
                    supersetMenu(for: name, in: groups)
                } label: {
                    Image(systemName: workout.supersetID(for: name) == nil ? "link" : "link.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(workout.supersetID(for: name) == nil ? .appTextSecondary : .appAccent)
                        .frame(width: 32, height: 32)
                        .overlay(alignment: .topTrailing) {
                            if workout.supersetID(for: name) == nil && !revenueCatService.canAccess(.supersets) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            if canReorder {
                Button {
                    Haptics.selection()
                    withAnimation {
                        isReorderingExercises = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                deleteExercise(named: name)
            } label: {
                IconTile(color: Color(red: 0.90, green: 0.30, blue: 0.24), size: 28) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            if canReorder {
                Haptics.selection()
                withAnimation {
                    isReorderingExercises = true
                }
            }
        }
    }

    /// Compact reorder mode: the workout collapses to one draggable row per exercise.
    @ViewBuilder
    private func reorderModeContent(blocks: [[(name: String, sets: [ExerciseSet])]]) -> some View {
        Section {
            ForEach(blocks, id: \.first!.name) { block in
                HStack(spacing: 12) {
                    Text(block.map(\.name).joined(separator: " + "))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(block.count == 2 ? "Superset" : "\(block[0].sets.count) sets")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(.vertical, 4)
            }
            .onMove(perform: moveExerciseBlocks)
        } header: {
            Text("Drag to reorder exercises")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appAccent)
                .textCase(nil)
        }
        .listRowBackground(Color.appSurface)
    }

    private func supersetPosition(
        for exerciseName: String,
        in groups: [(name: String, sets: [ExerciseSet])]
    ) -> Int? {
        guard let index = groups.firstIndex(where: { $0.name == exerciseName }),
              let groupID = groups[index].sets.first?.supersetGroupID else { return nil }
        let members = groups.indices.filter { groups[$0].sets.first?.supersetGroupID == groupID }
        guard let memberIndex = members.firstIndex(of: index) else { return nil }
        return memberIndex + 1
    }

    @ViewBuilder
    private func supersetMenu(
        for exerciseName: String,
        in groups: [(name: String, sets: [ExerciseSet])]
    ) -> some View {
        if let index = groups.firstIndex(where: { $0.name == exerciseName }) {
            if workout.supersetID(for: exerciseName) != nil {
                Button("Remove Superset", role: .destructive) {
                    workout.removeSuperset(containing: exerciseName)
                    persistWorkoutEdit()
                    Haptics.selection()
                }
            } else {
                if index > 0, workout.supersetID(for: groups[index - 1].name) == nil {
                    Button("Pair with \(groups[index - 1].name)") {
                        createSuperset(groups[index - 1].name, exerciseName)
                    }
                }
                if index + 1 < groups.count, workout.supersetID(for: groups[index + 1].name) == nil {
                    Button("Pair with \(groups[index + 1].name)") {
                        createSuperset(exerciseName, groups[index + 1].name)
                    }
                }
            }
        }
    }

    private func rowBackground(for group: (name: String, sets: [ExerciseSet])) -> some View {
        ZStack(alignment: .leading) {
            Color.appCanvas
            if group.sets.first?.supersetGroupID != nil {
                Rectangle().fill(Color.appAccent).frame(width: 3)
            }
        }
    }

    var body: some View {
        ZStack {
            Color.appCanvas.ignoresSafeArea()

            List {
                Section {
                    TextField("Workout Name", text: $workout.title)
                        .font(.title.bold())
                        .textFieldStyle(.plain)
                        .onChange(of: workout.title) { _, _ in
                            persistWorkoutEdit()
                        }

                    TextField(
                        "Workout Notes",
                        text: Binding(
                            get: { workout.notes ?? "" },
                            set: { workout.notes = $0 }
                        )
                    )
                    .font(.subheadline.bold())
                    .textFieldStyle(.plain)
                    .onChange(of: workout.notes) { _, _ in
                        persistWorkoutEdit()
                    }

                    HStack(spacing: 10) {
                        IconTile(color: Color(red: 0.36, green: 0.42, blue: 0.90), size: 28) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                        }
                        Text(
                            workout.date.formatted(
                                .dateTime.weekday(.wide).month(.wide).day().year()
                            )
                        )
                        .foregroundColor(Color(.secondaryLabel))
                    }

                    if let completedAt = workout.completedAt {
                        HStack(spacing: 10) {
                            IconTile(color: Color(red: 0.95, green: 0.55, blue: 0.19), size: 28) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appTextPrimary)
                            }
                            Text(formattedDuration(from: workout.createdAt, to: completedAt))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                }
                .listRowBackground(Color.appCanvas)
                .listRowSeparator(.hidden)

                // Grouping walks and sorts every set, so compute it once per render here and hand
                // the result down instead of re-deriving it per exercise row.
                let groups = exerciseGroups
                if isReorderingExercises {
                    reorderModeContent(blocks: exerciseBlocks)
                } else {
                    ForEach(groups, id: \.name) { group in
                        Section {
                            exerciseTitleRow(group.name, groups: groups, canReorder: groups.count > 1)

                            ExerciseNoteField(workout: workout, exerciseName: group.name)

                            columnHeader

                            ForEach(group.sets) { set in
                                ExerciseSetView(exerciseSet: set)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteSet(set)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }

                            Button {
                                addSet(for: group.name)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Add Set")
                                }
                            }
                            .buttonStyle(WorkoutActionButtonStyle(tint: .appAccent, prominence: .plain))
                        }
                        .listRowBackground(rowBackground(for: group))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(isReorderingExercises ? .active : .inactive))
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isReorderingExercises {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.selection()
                        withAnimation {
                            isReorderingExercises = false
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appAccent)
                }
            }
        }
        .proPaywall(feature: $selectedProFeature)
    }

    private func formattedDuration(from startDate: Date, to endDate: Date) -> String {
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(startDate)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private var columnHeader: some View {
        HStack {
            Text("Set")
                .frame(width: 30, alignment: .center)

            Text("Previous")
                .frame(maxWidth: .infinity, alignment: .center)

            Text(WeightUnitPreference.shared.unit.label)
                .frame(width: 68, alignment: .center)

            Text("Reps")
                .frame(width: 68, alignment: .center)

            Image(systemName: "checkmark")
                .frame(width: 30, alignment: .center)
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }

    private func persistWorkoutEdit() {
        workout.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            print("Failed to save workout edit: \(error)")
        }
    }

    private func createSuperset(_ firstExercise: String, _ secondExercise: String) {
        guard revenueCatService.canAccess(.supersets) else {
            selectedProFeature = .supersets
            return
        }
        workout.setSuperset(firstExercise, secondExercise)
        persistWorkoutEdit()
        Haptics.selection()
    }

    private func deleteExercise(named name: String) {
        for set in sets(for: name) {
            workout.exerciseSets.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }
        workout.normalizeSupersets()
        persistWorkoutEdit()
        Haptics.impact(.medium)
    }

    /// Removes a set and renumbers the remaining sets for that exercise so "Set N" stays sequential.
    private func deleteSet(_ set: ExerciseSet) {
        let exercise = set.exercise
        workout.preserveExerciseNote(beforeDeleting: set)
        workout.exerciseSets.removeAll { $0.id == set.id }
        modelContext.delete(set)

        let remaining = workout.exerciseSets
            .filter { $0.exercise.id == exercise.id }
            .sorted { $0.order < $1.order }
        for (index, remainingSet) in remaining.enumerated() {
            remainingSet.order = index
        }

        workout.normalizeSupersets()

        persistWorkoutEdit()
        Haptics.impact(.medium)
    }

    private func addSet(for exerciseName: String) {
        let existingSets = sets(for: exerciseName)
        guard let exercise = existingSets.first?.exercise else { return }
        let lastSet = existingSets.max { $0.order < $1.order }

        let newSet = ExerciseSet(
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
            order: (lastSet?.order ?? -1) + 1,
            exerciseOrder: lastSet?.exerciseOrder ?? 0,
            exercise: exercise,
            workout: workout,
            supersetGroupID: lastSet?.supersetGroupID
        )
        workout.exerciseSets.append(newSet)
        modelContext.insert(newSet)
        persistWorkoutEdit()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
        configurations: config
    )

    let exercise = Exercise(name: "Bench Press")
    let workout = Workout(title: "Push Day", date: .now, completedAt: .now)
    container.mainContext.insert(exercise)
    container.mainContext.insert(workout)
    let set = ExerciseSet(weight: 135, reps: 8, order: 0, exercise: exercise, workout: workout)
    container.mainContext.insert(set)
    workout.exerciseSets.append(set)

    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
    .environmentObject(RevenueCatService.shared)
}
