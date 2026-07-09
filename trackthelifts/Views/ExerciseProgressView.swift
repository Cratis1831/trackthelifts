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

    // Cached in @State and fetched on appear rather than computed in `body`: the history backs a
    // SwiftData fetch and `body` reads it many times per render (summary cards, chart, list).
    @State private var history: [ProgressStatsService.ExerciseHistoryPoint] = []
    /// Distinguishes "not fetched yet" from "fetched and genuinely empty", so the empty state
    /// doesn't flash for one frame before the first fetch completes.
    @State private var hasLoadedHistory = false

    // Raw date bound to `chartXSelection` (cleared by the system on finger lift) plus a persisted
    // snapped point that keeps the callout visible after the gesture ends.
    @State private var rawSelectedDate: Date?
    @State private var selectedPoint: ProgressStatsService.ExerciseHistoryPoint?

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
                if hasLoadedHistory {
                    emptyState
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summaryRow

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Estimated 1RM Over Time")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            Chart {
                                ForEach(history) { point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Est. 1RM", point.estimated1RM)
                                    )
                                    .foregroundStyle(Color.appAccent)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", point.date),
                                        y: .value("Est. 1RM", point.estimated1RM)
                                    )
                                    .foregroundStyle(Color.appAccent)
                                }

                                if let sel = selectedPoint {
                                    RuleMark(x: .value("Date", sel.date))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                        .lineStyle(StrokeStyle(lineWidth: 1))
                                        .annotation(
                                            position: .top,
                                            spacing: 0,
                                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                                        ) {
                                            ChartCalloutView(
                                                title: sel.date.formatted(date: .abbreviated, time: .omitted),
                                                value: "~\(sel.estimated1RM.formattedWeight) \(WeightUnitPreference.shared.unit.label) est. 1RM",
                                                detail: "\(sel.weight.formattedWeight) \(WeightUnitPreference.shared.unit.label) \u{00D7} \(sel.reps)"
                                            )
                                        }

                                    PointMark(
                                        x: .value("Date", sel.date),
                                        y: .value("Est. 1RM", sel.estimated1RM)
                                    )
                                    .symbolSize(120)
                                    .foregroundStyle(Color.appAccent)
                                }
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .chartXSelection(value: $rawSelectedDate)
                            .onChange(of: rawSelectedDate) { old, new in
                                guard let new else { return }
                                guard var snapped = history.nearest(to: new, by: \.date) else { return }
                                // Sets from the same workout share one completedAt date; among such
                                // ties show the best set of the day.
                                let tied = history.filter { $0.date == snapped.date }
                                if let best = tied.max(by: { $0.estimated1RM < $1.estimated1RM }) {
                                    snapped = best
                                }
                                if old == nil, snapped.id == selectedPoint?.id {
                                    selectedPoint = nil
                                } else if snapped.id != selectedPoint?.id {
                                    selectedPoint = snapped
                                    Haptics.selection()
                                }
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
        .onAppear {
            selectedPoint = nil
            history = ProgressStatsService.history(for: exercise, in: modelContext)
            hasLoadedHistory = true
        }
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
                .foregroundColor(.appAccent)
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
