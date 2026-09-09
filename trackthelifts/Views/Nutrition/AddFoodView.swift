//
//  AddFoodView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct AddFoodView: View {
    let selectedDay: Date
    let customFoods: [CustomFood]

    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedMeal: MealType = defaultMeal(for: .now)
    @State private var isManualPresented = false
    @State private var selectedProFeature: ProFeature?
    @State private var comingSoonFeature: ProFeature?

    private var filteredFoods: [CustomFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(customFoods.prefix(8))
        }
        return customFoods.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
            || ($0.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        mealPicker
                        searchField
                        entryMethods
                        if !filteredFoods.isEmpty {
                            recentSection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
            .sheet(isPresented: $isManualPresented) {
                ManualFoodEntryView(selectedDay: selectedDay, mealType: selectedMeal)
            }
            .sheet(item: $comingSoonFeature) { feature in
                NutritionComingSoonView(feature: feature)
            }
            .proPaywall(feature: $selectedProFeature)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Picker("Meal", selection: $selectedMeal) {
                ForEach(MealType.allCases) { meal in
                    Text(meal.displayName).tag(meal)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appTextSecondary)
            TextField("Search foods...", text: $query)
                .foregroundColor(.appTextPrimary)
                .textInputAutocapitalization(.words)
        }
        .appInputSurface()
    }

    private var entryMethods: some View {
        VStack(alignment: .leading, spacing: 10) {
            methodButton(title: "Add Manually", systemImage: "square.and.pencil", feature: nil) {
                isManualPresented = true
            }
            methodButton(title: "Scan Barcode", systemImage: "barcode.viewfinder", feature: .barcodeScan) {
                handleAdvanced(.barcodeScan)
            }
            methodButton(title: "Take Food Photo", systemImage: "camera.fill", feature: .foodPhoto) {
                handleAdvanced(.foodPhoto)
            }
            methodButton(title: "Describe with AI", systemImage: "text.bubble.fill", feature: .aiDescribe) {
                handleAdvanced(.aiDescribe)
            }
        }
    }

    private func methodButton(
        title: String,
        systemImage: String,
        feature: ProFeature?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(color: .appAccent) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                if let feature, revenueCatService.requiresPro(feature) {
                    ProBadge()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextTertiary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(query.isEmpty ? "Recent" : "Matches")
                .font(.appUtility)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(.appTextSecondary)

            ForEach(filteredFoods, id: \.id) { food in
                Button {
                    isManualPresented = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(food.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.appTextPrimary)
                            Text("\(Int(food.calories.rounded())) kcal · \(food.servingDescription ?? "1 serving")")
                                .font(.appCaption)
                                .foregroundColor(.appTextSecondary)
                        }
                        Spacer()
                    }
                    .appCard(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleAdvanced(_ feature: ProFeature) {
        if revenueCatService.canAccess(feature) {
            comingSoonFeature = feature
        } else {
            selectedProFeature = feature
        }
    }

    private static func defaultMeal(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }
}
