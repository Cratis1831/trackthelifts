//
//  ChartCallout.swift
//  TrackTheLifts
//

import SwiftUI

/// Small info bubble shown above a selected chart mark, styled like the app's dark cards.
struct ChartCalloutView: View {
    let title: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appAccent)

            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
        )
    }
}

extension Array {
    /// Element whose date (read via `dateKeyPath`) is closest to `date`. Used to snap a chart's
    /// raw X-axis selection to the nearest actual data point.
    func nearest(to date: Date, by dateKeyPath: KeyPath<Element, Date>) -> Element? {
        self.min(by: {
            abs($0[keyPath: dateKeyPath].timeIntervalSince(date)) <
                abs($1[keyPath: dateKeyPath].timeIntervalSince(date))
        })
    }
}
