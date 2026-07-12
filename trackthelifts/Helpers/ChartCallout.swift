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
                .font(.appUtility)
                .foregroundColor(Color.appTextSecondary)

            Text(value)
                .font(.appMetric)
                .foregroundColor(.appAccent)

            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        }
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
