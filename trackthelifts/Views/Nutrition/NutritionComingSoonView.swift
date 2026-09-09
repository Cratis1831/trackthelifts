//
//  NutritionComingSoonView.swift
//  TrackTheLifts
//

import SwiftUI

struct NutritionComingSoonView: View {
    let feature: ProFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                VStack(spacing: 20) {
                    IconTile(color: feature.iconColor, size: 52) {
                        Image(systemName: feature.systemImage)
                            .font(.system(size: 22, weight: .semibold))
                    }

                    Text(feature.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.appTextPrimary)

                    Text("This Pro tool is included in your subscription. The food database and AI logging connect in the next 2.0 update — you can still log manually today.")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)

                    Button("Close") { dismiss() }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .padding(.horizontal, 28)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }
}
