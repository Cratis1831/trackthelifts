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
                .activitySystemActionForegroundColor(context.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.title3)
                            .foregroundStyle(context.accentColor)
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
                        .foregroundStyle(context.accentColor)
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
                        .tint(context.accentColor)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(context.accentColor)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
                    .foregroundStyle(context.accentColor)
            } minimal: {
                ProgressView(
                    timerInterval: context.state.startDate...context.state.endDate,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(context.accentColor)
                }
                .progressViewStyle(.circular)
                .tint(context.accentColor)
            }
            .keylineTint(context.accentColor)
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
                        .foregroundStyle(context.accentColor)
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
                    .foregroundStyle(context.accentColor)
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
            .tint(context.accentColor)
        }
        .padding(16)
    }
}

private extension ActivityViewContext where Attributes == RestTimerActivityAttributes {
    var accentColor: Color {
        switch attributes.accentTheme {
        case "white": .white
        case "orange": .orange
        case "red": .red
        case "pink": .pink
        case "purple": .purple
        case "indigo": .indigo
        case "blue": .blue
        case "teal": .teal
        case "green": .green
        default: .indigo
        }
    }
}
