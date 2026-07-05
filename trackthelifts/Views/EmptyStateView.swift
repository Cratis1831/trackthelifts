//
//  EmptyStateView.swift
//  TrackTheLifts
//

import SwiftUI

/// Shared "nothing here yet" placeholder used across the app's list/chart screens.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        EmptyStateView(
            systemImage: "clock.badge.checkmark",
            title: "No Completed Workouts",
            message: "Your workout history will appear here once you complete your first workout."
        )
    }
}
