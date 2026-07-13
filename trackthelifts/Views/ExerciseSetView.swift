//
//  ExerciseSetView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-14.
//

import SwiftUI
import SwiftData

struct ExerciseSetView: View {
    let exerciseSet: ExerciseSet
    var onPersonalRecord: ((ExerciseSet, PRKind) -> Void)? = nil
    /// When set, this view claims focus for its weight field if its id matches the pending value,
    /// then clears the binding so the focus request only fires once.
    var autoFocusSetID: Binding<UUID?>? = nil
    @Environment(\.modelContext) private var modelContext

    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var isCompleted: Bool = false
    @State private var showClassificationDialog: Bool = false
    @State private var intensityPreference = IntensityPreference.shared
    @State private var isShakingCompletion = false
    @State private var completionShakeOffset: CGFloat = 0
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    // Cached in @State and computed on appear / on completion rather than in `body`. Both back a
    // SwiftData fetch, and doing them in `body` re-ran the fetches on every redraw — the main
    // cause of scroll jank on a workout with many sets. The underlying data is stable during a
    // session ("previous" is historical; PR status only changes when this set is completed).
    @State private var previousSummary: String = "- -"
    @State private var isPersonalRecord: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
        HStack {
            // Column 1: Set number. Long-press to classify this set (warm-up/working/failure) -
            // the classification is stored on this exerciseSet only, so it never affects other
            // sets or other exercises.
            ZStack(alignment: .topTrailing) {
                Text("\(exerciseSet.order + 1)")
                    .font(.appUtility)
                    .frame(width: 30, height: 32)
                    .background(Color.appElevatedSurface)
                    .cornerRadius(6)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isPersonalRecord ? Color.yellow : (isCompleted ? Color.appAccent : Color.appBorder),
                                lineWidth: 1
                            )
                    }

                if let badgeText = exerciseSet.classification.badgeText {
                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .frame(width: 14, height: 14)
                        .background(exerciseSet.classification == .warmup ? Color.blue : Color.red)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture {
                Haptics.selection()
                showClassificationDialog = true
            }
            .confirmationDialog(
                "Classify Set \(exerciseSet.order + 1)",
                isPresented: $showClassificationDialog,
                titleVisibility: .visible
            ) {
                ForEach(SetClassification.allCases, id: \.self) { classification in
                    Button(classification.label + (classification == exerciseSet.classification ? " (current)" : "")) {
                        setClassification(classification)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }

            // Column 2 & 3: Previous summary (last time this exercise/set-number was logged)
            Text(previousSummary)
                .font(.appUtility)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(Color.secondary)

            // Column 4: weight
            TextField("0", text: $weight)
                .font(.appUtility)
                .frame(width: 68, height: 32)
                .textFieldStyle(.plain)
                .background(Color.appElevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isWeightFocused ? Color.appAccent : Color.appBorder, lineWidth: 1)
                }
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .focused($isWeightFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: weight) { _, newValue in
                    updateExerciseSet()
                }
                .onChange(of: isWeightFocused) { _, focused in
                    selectAllText(if: focused)
                }
                .onSubmit {
                    isRepsFocused = true
                }

            // Column 5: reps
            TextField("0", text: $reps)
                .font(.appUtility)
                .frame(width: 68, height: 32)
                .textFieldStyle(.plain)
                .background(Color.appElevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRepsFocused ? Color.appAccent : Color.appBorder, lineWidth: 1)
                }
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .focused($isRepsFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: reps) { _, newValue in
                    updateExerciseSet()
                }
                .onChange(of: isRepsFocused) { _, focused in
                    selectAllText(if: focused)
                }
                .onSubmit {
                    isRepsFocused = false
                    isWeightFocused = false
                }

            // Column 6: checkmark. A rounded square matching the SF Symbol icon tiles (see
            // `IconTile`): same continuous corner radius and 30pt size, filled when completed.
            Button {
                toggleCompletion()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                        .fill(isCompleted ? Color.appAccent : Color.clear)
                    RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                        .strokeBorder(isCompleted ? Color.clear : Color.secondary, lineWidth: 1.5)
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.onAppAccent)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: completionShakeOffset)
        }

            if let metric = displayedIntensityMetric {
                intensityMenu(for: metric)
            }
        }
        .onAppear {
            loadExerciseSetData()
            if let autoFocusSetID, autoFocusSetID.wrappedValue == exerciseSet.id {
                isWeightFocused = true
                autoFocusSetID.wrappedValue = nil
            }
        }
        // Settings converts the underlying `exerciseSet.weight` in place when the user switches
        // lbs/kg, but this view's weight field is cached in @State for scroll-perf reasons (see
        // above), so it won't pick up that change on its own if this row was already on screen
        // (e.g. an in-progress workout left open in the background) — reload it explicitly.
        .onChange(of: WeightUnitPreference.shared.unit) { _, _ in
            loadExerciseSetData()
        }
    }

    private var displayedIntensityMetric: IntensityMetric? {
        exerciseSet.intensityMetric ?? intensityPreference.mode.metric
    }

    private func intensityMenu(for metric: IntensityMetric) -> some View {
        Menu {
            ForEach(metric.values, id: \.self) { value in
                Button {
                    setIntensity(metric: metric, value: value)
                } label: {
                    if exerciseSet.intensityMetric == metric && exerciseSet.intensityValue == value {
                        Label(metric.formatted(value), systemImage: "checkmark")
                    } else {
                        Text(metric.formatted(value))
                    }
                }
            }

            if exerciseSet.intensityValue != nil {
                Divider()
                Button("Clear", role: .destructive) {
                    clearIntensity()
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(metric.label)
                Text(exerciseSet.intensityValue.map(metric.formatted) ?? "–")
                    .foregroundColor(exerciseSet.intensityValue == nil ? .appTextSecondary : .appTextPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.appAccent)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Color.appElevatedSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(Color.appAccent.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(metric.label) effort")
        .accessibilityValue(exerciseSet.intensityValue.map(metric.formatted) ?? "Not set")
    }
    
    /// Selects the full text of whichever weight/reps field just gained focus, so tapping into a
    /// field that already has a value lets the user immediately type over it instead of having to
    /// manually clear it first.
    private func selectAllText(if focused: Bool) {
        guard focused else { return }
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
        }
    }

    /// Recomputes the cached PR highlight. Called on appear and whenever completion toggles — not
    /// from `body` — since it runs a fetch over the exercise's completed-set history.
    private func refreshPersonalRecordFlag() {
        isPersonalRecord = isCompleted
            && PersonalRecordService.personalRecord(for: exerciseSet, in: modelContext) != nil
    }

    /// Recomputes the cached "previous" summary. Historical (prior completed workouts), so it's
    /// stable for the session and only needs to run on appear.
    private func refreshPreviousSummary() {
        guard let previous = fetchPreviousSet() else {
            previousSummary = "- -"
            return
        }
        previousSummary = "\(previous.weight.formattedWeight) \(WeightUnitPreference.shared.unit.label) x \(previous.reps)"
    }

    private func fetchPreviousSet() -> ExerciseSet? {
        let exerciseID = exerciseSet.exercise.id
        let workoutID = exerciseSet.workout.id
        let order = exerciseSet.order
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { set in
                set.exercise.id == exerciseID && set.workout.id != workoutID && set.order == order
                    && set.workout.completedAt != nil && !set.workout.isDeleted
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func loadExerciseSetData() {
        weight = exerciseSet.weight > 0 ? exerciseSet.weight.formattedWeight : ""
        reps = exerciseSet.reps > 0 ? String(exerciseSet.reps) : ""
        isCompleted = exerciseSet.isCompleted
        refreshPreviousSummary()
        refreshPersonalRecordFlag()
    }
    
    private func updateExerciseSet() {
        if let weightValue = Double(weight) {
            exerciseSet.weight = weightValue
        } else {
            exerciseSet.weight = 0
        }
        
        if let repsValue = Int(reps) {
            exerciseSet.reps = repsValue
        } else {
            exerciseSet.reps = 0
        }
        
        exerciseSet.updatedAt = .now
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update exercise set: \(error)")
        }
    }
    
    private func setClassification(_ classification: SetClassification) {
        guard exerciseSet.classification != classification else { return }
        exerciseSet.setType = classification
        exerciseSet.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            print("Failed to update set classification: \(error)")
        }

        Haptics.selection()
    }

    private func setIntensity(metric: IntensityMetric, value: Double) {
        exerciseSet.intensityMetric = metric
        exerciseSet.intensityValue = value
        exerciseSet.updatedAt = .now
        do {
            try modelContext.save()
            Haptics.selection()
        } catch {
            print("Failed to save set intensity: \(error)")
        }
    }

    private func clearIntensity() {
        exerciseSet.intensityMetric = nil
        exerciseSet.intensityValue = nil
        exerciseSet.updatedAt = .now
        do {
            try modelContext.save()
            Haptics.selection()
        } catch {
            print("Failed to clear set intensity: \(error)")
        }
    }

    @MainActor
    private func shakeInvalidCompletion() {
        guard !isShakingCompletion else { return }
        isShakingCompletion = true
        Haptics.error()

        Task { @MainActor in
            for offset: CGFloat in [-6, 6, -4, 4, -2, 2, 0] {
                withAnimation(.easeInOut(duration: 0.055)) {
                    completionShakeOffset = offset
                }
                try? await Task.sleep(for: .milliseconds(55))
            }
            isShakingCompletion = false
        }
    }

    private func toggleCompletion() {
        // Weight is optional (defaults to 0, e.g. for bodyweight exercises), but reps are required.
        let weightValue = Double(weight) ?? 0
        guard let repsValue = Int(reps), repsValue > 0 else {
            shakeInvalidCompletion()
            return
        }

        let wasCompleted = isCompleted
        isCompleted.toggle()
        exerciseSet.isCompleted = isCompleted
        exerciseSet.updatedAt = .now

        // Update the exercise set with current values
        exerciseSet.weight = weightValue
        exerciseSet.reps = repsValue

        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle completion: \(error)")
        }

        if !wasCompleted && isCompleted {
            Haptics.impact(.light)
            RestTimerManager.shared.startTimer(for: exerciseSet.exercise.name)
            // Compute the PR once here and reuse it for both the announcement and the cached
            // highlight, so `body` never has to fetch.
            let prKind = PersonalRecordService.personalRecord(for: exerciseSet, in: modelContext)
            isPersonalRecord = prKind != nil
            if let prKind {
                onPersonalRecord?(exerciseSet, prKind)
            }
        } else if wasCompleted && !isCompleted {
            isPersonalRecord = false
            Haptics.selection()
        }
    }
}

#Preview {
    let workout = Workout(title: "New Workout", date: .now)
    let exercise = Exercise(name: "Bench Press")
    let exerciseSet = ExerciseSet(weight: 135, reps: 8, order: 0, exercise: exercise, workout: workout)
    ExerciseSetView(exerciseSet: exerciseSet)
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
