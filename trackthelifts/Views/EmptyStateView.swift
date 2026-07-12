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
            AppStatusBadge(text: "Ready when you are")

            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundColor(Color.appTextSecondary)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.appTextPrimary)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .padding(.horizontal, 40)
            }
        }
        .padding(.vertical, 24)
    }
}

#Preview {
    ZStack {
        Color.appCanvas.ignoresSafeArea()
        EmptyStateView(
            systemImage: "clock.badge.checkmark",
            title: "No Completed Workouts",
            message: "Your workout history will appear here once you complete your first workout."
        )
    }
}
