//
//  TimerView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import SwiftUI

/// Elapsed-time stopwatch anchored to a fixed `startDate` rather than view-mount time, so it
/// keeps counting correctly across minimizing/resuming a workout (which recreates this view).
struct TimerView: View {
    let startDate: Date

    @State private var now = Date()

    // Timer that updates every second
    private let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        Text(formattedElapsedTime)
            .font(.appUtility)
            .monospacedDigit()
            .foregroundColor(.appTextSecondary)
            .onReceive(timer) { value in
                now = value
            }
    }

    private var formattedElapsedTime: String {
        let totalSeconds = max(0, Int(now.timeIntervalSince(startDate)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}
