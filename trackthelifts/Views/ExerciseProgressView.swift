//
//  ExerciseProgressView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseProgressView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext

    private var history: [ProgressStatsService.ExerciseHistoryPoint] {
        ProgressStatsService.history(for: exercise, in: modelContext)
    }

    private var bestWeight: Double {
        history.map(\.weight).max() ?? 0
    }

    private var best1RM: Double {
        history.map(\.estimated1RM).max() ?? 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if history.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summaryRow

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Estimated 1RM Over Time")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            Chart(history) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Est. 1RM", point.estimated1RM)
                                )
                                .foregroundStyle(Color.orange)
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Est. 1RM", point.estimated1RM)
                                )
                                .foregroundStyle(Color.orange)
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("History")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            VStack(spacing: 8) {
                                ForEach(history.reversed()) { point in
                                    historyRow(point)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Best Weight", value: "\(bestWeight.formattedWeight) \(WeightUnitPreference.shared.unit.label)")
            summaryCard(title: "Est. 1RM", value: "\(best1RM.formattedWeight) \(WeightUnitPreference.shared.unit.label)")
            summaryCard(title: "Sets Logged", value: "\(history.count)")
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.orange)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(12)
    }

    private func historyRow(_ point: ProgressStatsService.ExerciseHistoryPoint) -> some View {
        HStack {
            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.76, green: 0.76, blue: 0.78))

            Spacer()

            Text("\(point.weight.formattedWeight) \(WeightUnitPreference.shared.unit.label) \u{00D7} \(point.reps)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(10)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "No History Yet",
            message: "Complete a set of \(exercise.name) to start tracking progress."
        )
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Exercise.self, ExerciseSet.self, Workout.self, Bodypart.self,
        configurations: config
    )

    let exercise = Exercise(name: "Bench Press")
    container.mainContext.insert(exercise)

    return NavigationStack {
        ExerciseProgressView(exercise: exercise)
    }
    .modelContainer(container)
}
