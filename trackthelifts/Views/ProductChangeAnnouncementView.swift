//
//  ProductChangeAnnouncementView.swift
//  TrackTheLifts
//

import SwiftUI

/// One-time v2.0 sheet: training is free; Pro is nutrition.
struct ProductChangeAnnouncementView: View {
    var onContinue: () -> Void
    var onOpenNutrition: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()
                PrecisionGridBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 10) {
                                AppStatusBadge(text: "Version 2.0")

                                Text("Training is now free.")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("ForgeLyte Lift's workout tracker is free for everyone — logging, history, unlimited routines, supersets, effort tracking, charts, themes, and iCloud workout sync.")
                                    .font(.appBody)
                                    .foregroundColor(.appTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            announcementCard(
                                icon: "dumbbell.fill",
                                color: Color(red: 0.20, green: 0.48, blue: 0.96),
                                title: "Free",
                                detail: "The lifting app you already use, with every training feature unlocked."
                            )

                            announcementCard(
                                icon: "fork.knife",
                                color: .appAccent,
                                title: "ForgeLyte Pro",
                                detail: "Optional nutrition: calories, macros, food search, barcode scanning, and AI meal logging when you’re ready."
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }

                    VStack(spacing: 10) {
                        Button("Open Nutrition", action: onOpenNutrition)
                            .buttonStyle(AppPrimaryButtonStyle())

                        Button("Continue", action: onContinue)
                            .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private func announcementCard(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(color: color) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .appCard()
    }
}
