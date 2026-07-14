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
                        releaseCard(release)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func releaseCard(_ release: AppRelease) -> some View {
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
