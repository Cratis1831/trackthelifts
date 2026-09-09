//
//  FoodDataSourcesView.swift
//  TrackTheLifts
//

import SwiftUI

struct FoodDataSourcesView: View {
    var body: some View {
        ZStack {
            Color.appCanvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ForgeLyte may include nutrition data from public and community sources. Each search result and logged food shows its source. USDA records can be cached. Open Food Facts records are stored separately and never mixed into the USDA catalogue.")
                        .font(.appBody)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    sourceCard(
                        title: "USDA FoodData Central",
                        body: "Nutrition data may include data from U.S. Department of Agriculture, Agricultural Research Service, FoodData Central.",
                        linkTitle: "fdc.nal.usda.gov",
                        url: AppLinks.usdaFoodDataCentral,
                        color: Color(red: 0.30, green: 0.72, blue: 0.40)
                    )

                    sourceCard(
                        title: "Open Food Facts",
                        body: "Contains information from Open Food Facts, made available under the Open Database License (ODbL).",
                        linkTitle: "world.openfoodfacts.org",
                        url: AppLinks.openFoodFacts,
                        color: Color(red: 0.95, green: 0.55, blue: 0.19),
                        secondaryLinkTitle: "ODbL 1.0",
                        secondaryURL: AppLinks.odblLicense
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Food Data Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceCard(
        title: String,
        body: String,
        linkTitle: String,
        url: URL,
        color: Color,
        secondaryLinkTitle: String? = nil,
        secondaryURL: URL? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconTile(color: color) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }

            Text(body)
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: url) {
                Text(linkTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appAccent)
            }

            if let secondaryLinkTitle, let secondaryURL {
                Link(destination: secondaryURL) {
                    Text(secondaryLinkTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appAccent)
                }
            }
        }
        .appCard()
    }
}
