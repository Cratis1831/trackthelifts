//
//  ManualFoodEntryView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct ManualFoodEntryView: View {
    var existingLog: FoodLog? = nil
    let selectedDay: Date
    var mealType: MealType = .lunch

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var selectedMeal: MealType
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var quantity = "1"

    init(existingLog: FoodLog? = nil, selectedDay: Date, mealType: MealType = .lunch) {
        self.existingLog = existingLog
        self.selectedDay = selectedDay
        self.mealType = existingLog?.mealType ?? mealType
        _selectedMeal = State(initialValue: existingLog?.mealType ?? mealType)
        _name = State(initialValue: existingLog?.displayName ?? "")
        _brand = State(initialValue: existingLog?.brand ?? "")
        _calories = State(initialValue: existingLog.map { String(Int($0.calories.rounded())) } ?? "")
        _protein = State(initialValue: existingLog.map { String(Int($0.proteinGrams.rounded())) } ?? "")
        _carbs = State(initialValue: existingLog.map { String(Int($0.carbsGrams.rounded())) } ?? "")
        _fat = State(initialValue: existingLog.map { String(Int($0.fatGrams.rounded())) } ?? "")
        _quantity = State(initialValue: existingLog.map { String($0.quantity) } ?? "1")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(calories) ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        labeledField("Food", text: $name, placeholder: "Chicken breast")
                        labeledField("Brand", text: $brand, placeholder: "Optional")

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

                        labeledField("Calories", text: $calories, placeholder: "0", keyboard: .decimalPad)
                        HStack(spacing: 10) {
                            labeledField("Protein (g)", text: $protein, placeholder: "0", keyboard: .decimalPad)
                            labeledField("Carbs (g)", text: $carbs, placeholder: "0", keyboard: .decimalPad)
                            labeledField("Fat (g)", text: $fat, placeholder: "0", keyboard: .decimalPad)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existingLog == nil ? "Manual Entry" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .foregroundColor(.appTextPrimary)
                .appInputSurface()
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let caloriesValue = Double(calories) ?? 0
        let proteinValue = Double(protein) ?? 0
        let carbsValue = Double(carbs) ?? 0
        let fatValue = Double(fat) ?? 0
        let quantityValue = Double(quantity) ?? 1
        let brandValue = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let loggedAt: Date = {
            if Calendar.current.isDate(selectedDay, inSameDayAs: .now) {
                return existingLog?.loggedAt ?? .now
            }
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        }()

        if let existingLog {
            existingLog.displayName = trimmedName
            existingLog.brand = brandValue.isEmpty ? nil : brandValue
            existingLog.mealType = selectedMeal
            existingLog.calories = caloriesValue
            existingLog.proteinGrams = proteinValue
            existingLog.carbsGrams = carbsValue
            existingLog.fatGrams = fatValue
            existingLog.quantity = quantityValue
            existingLog.loggedAt = loggedAt
        } else {
            let log = FoodLog(
                loggedAt: loggedAt,
                mealType: selectedMeal,
                sourceType: .manual,
                displayName: trimmedName,
                brand: brandValue.isEmpty ? nil : brandValue,
                quantity: quantityValue,
                calories: caloriesValue,
                proteinGrams: proteinValue,
                carbsGrams: carbsValue,
                fatGrams: fatValue
            )
            modelContext.insert(log)
            upsertCustomFood(
                name: trimmedName,
                brand: brandValue.isEmpty ? nil : brandValue,
                calories: caloriesValue,
                protein: proteinValue,
                carbs: carbsValue,
                fat: fatValue
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private func upsertCustomFood(
        name: String,
        brand: String?,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) {
        let descriptor = FetchDescriptor<CustomFood>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if let match = existing.first(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                && ($0.brand ?? "") == (brand ?? "")
        }) {
            match.calories = calories
            match.proteinGrams = protein
            match.carbsGrams = carbs
            match.fatGrams = fat
            match.lastUsedAt = .now
            return
        }

        let food = CustomFood(
            name: name,
            brand: brand,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            lastUsedAt: .now
        )
        modelContext.insert(food)
    }
}
