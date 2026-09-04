//
//  WhatsNewView.swift
//  TrackTheLifts
//

import SwiftUI

struct WhatsNewView: View {
    var body: some View {
        ZStack {
            Color.appCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ReleaseCatalog.releases) { release in
                        WhatsNewReleaseCard(release: release)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Post-update sheet for the current marketing version only. Dismissing records that version
/// so it does not return until the next release (or a reinstall, which clears UserDefaults).
struct WhatsNewUpdateSheet: View {
    let release: AppRelease
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        WhatsNewReleaseCard(release: release)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Button("Continue", action: onDismiss)
                        .buttonStyle(AppPrimaryButtonStyle())
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
}

private struct WhatsNewReleaseCard: View {
    let release: AppRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Version \(release.version)")
                    .font(.appSectionTitle)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                if release.version == AppVersion.marketingVersion {
                    AppStatusBadge(text: "Current")
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(release.notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(note)
                            .font(.appBody)
                            .foregroundStyle(Color.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .appCard()
    }
}

#Preview {
    NavigationStack {
        WhatsNewView()
    }
}
