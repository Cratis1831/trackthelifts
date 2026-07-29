//
//  RestTimerLiveActivity.swift
//  TrackTheLiftsWidgets
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen banner + Dynamic Island presentations for the in-gym rest timer. The countdown
/// text and progress ring are system-rendered over `startDate...endDate`, so they tick without
/// any updates from the app process.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            LockScreenRestTimerView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("Rest")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .foregroundStyle(.orange)
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.exerciseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        ProgressView(
                            timerInterval: context.state.startDate...context.state.endDate,
                            countsDown: true
                        ) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(.orange)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
                    .foregroundStyle(.orange)
            } minimal: {
                ProgressView(
                    timerInterval: context.state.startDate...context.state.endDate,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .progressViewStyle(.circular)
                .tint(.orange)
            }
            .keylineTint(.orange)
        }
    }
}

private struct LockScreenRestTimerView: View {
    let context: ActivityViewContext<RestTimerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("Rest Timer")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                    .foregroundStyle(.orange)
            }

            Text(context.attributes.exerciseName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: true
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.orange)
        }
        .padding(16)
    }
}
