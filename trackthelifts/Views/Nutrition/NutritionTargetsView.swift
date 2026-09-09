//
//  NutritionTargetsView.swift
//  TrackTheLifts
//

import SwiftUI

struct NutritionTargetsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targets = NutritionPreference.shared
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String

    init() {
        let preference = NutritionPreference.shared
        _calories = State(initialValue: preference.calories > 0 ? String(Int(preference.calories.rounded())) : "")
        _protein = State(initialValue: preference.proteinGrams > 0 ? String(Int(preference.proteinGrams.rounded())) : "")
        _carbs = State(initialValue: preference.carbsGrams > 0 ? String(Int(preference.carbsGrams.rounded())) : "")
        _fat = State(initialValue: preference.fatGrams > 0 ? String(Int(preference.fatGrams.rounded())) : "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Set daily targets. These stay on this device and are not stored in iCloud.")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        field("Calories", text: $calories)
                        field("Protein (g)", text: $protein)
                        field("Carbs (g)", text: $carbs)
                        field("Fat (g)", text: $fat)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        targets.calories = Double(calories) ?? 0
                        targets.proteinGrams = Double(protein) ?? 0
                        targets.carbsGrams = Double(carbs) ?? 0
                        targets.fatGrams = Double(fat) ?? 0
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .foregroundColor(.appTextPrimary)
                .appInputSurface()
        }
    }
}
