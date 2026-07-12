import SwiftUI

struct WorkoutCompletionSummary: Identifiable {
    let id = UUID()
    let workoutName: String
    let duration: TimeInterval
    let exerciseCount: Int
    let completedSetCount: Int
    let totalReps: Int
    let totalVolume: Double

    init(workout: Workout) {
        let completedSets = workout.exerciseSets.filter(\.isCompleted)
        workoutName = workout.title
        duration = max(0, (workout.completedAt ?? .now).timeIntervalSince(workout.createdAt))
        exerciseCount = Set(completedSets.map { $0.exercise.id }).count
        completedSetCount = completedSets.count
        totalReps = completedSets.reduce(0) { $0 + $1.reps }
        totalVolume = completedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var formattedDuration: String {
        let seconds = Int(duration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct WorkoutCompletionView: View {
    let summary: WorkoutCompletionSummary
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color.appAccent.opacity(0.18), lineWidth: 12)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0.05, to: 0.94)
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundColor(.appAccent)
                }
                .padding(.bottom, 18)

                Text("WORKOUT COMPLETE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundColor(.appAccent)

                Text(summary.workoutName)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 7)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                    completionStat("Duration", summary.formattedDuration)
                    completionStat("Exercises", "\(summary.exerciseCount)")
                    completionStat("Sets", "\(summary.completedSetCount)")
                    completionStat("Reps", "\(summary.totalReps)")
                }
                .background(Color.appBorder)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                .padding(.top, 24)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TOTAL VOLUME")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.3)
                            .foregroundColor(.appTextSecondary)
                        Text("\(summary.totalVolume.formattedWeight) \(WeightUnitPreference.shared.unit.label)")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent)
                }
                .padding(16)
                .background(Color.appElevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                .padding(.top, 12)

                Button("Done", action: onDone)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .padding(.top, 22)
            }
            .padding(24)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityAddTraits(.isModal)
    }

    private func completionStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(Color.appElevatedSurface)
    }
}
