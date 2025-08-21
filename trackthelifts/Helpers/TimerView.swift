//
//  TimerView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import SwiftUI

struct TimerView: View {
    @State private var startDate = Date()
    @State private var elapsedTime: TimeInterval = 0

    // Timer that updates every second
    private let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        HStack {
            Text(formattedElapsedTime)
                .monospacedDigit()
                .foregroundColor(Color(.secondaryLabel))
        }
        .onReceive(timer) { _ in
            elapsedTime = Date().timeIntervalSince(startDate)
        }
    }

    private var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}
