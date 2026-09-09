//
//  CopyMealSheet.swift
//  TrackTheLifts
//

import SwiftUI

struct CopyMealSheet: View {
    let title: String
    let sources: [MealCopying.Source]
    var destinationMeal: MealType
    var onCopy: (MealCopying.Source, MealType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeal: MealType

    init(
        title: String,
        sources: [MealCopying.Source],
        destinationMeal: MealType,
        onCopy: @escaping (MealCopying.Source, MealType) -> Void
    ) {
        self.title = title
        self.sources = sources
        self.destinationMeal = destinationMeal
        self.onCopy = onCopy
        _selectedMeal = State(initialValue: destinationMeal)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                if sources.isEmpty {
                    VStack(spacing: 10) {
                        Text("No meals to copy")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text("Log foods for up to five days, then copy a meal from here.")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add to")
                                    .font(.appCaption)
                                    .foregroundColor(.appTextSecondary)
                                Picker("Meal", selection: $selectedMeal) {
                                    ForEach(MealType.allCases) { meal in
                                        Text(meal.displayName).tag(meal)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("From the last \(MealCopying.lookbackDays) days")
                                    .font(.appUtility)
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundColor(.appTextSecondary)

                                ForEach(sources) { source in
                                    Button {
                                        onCopy(source, selectedMeal)
                                        dismiss()
                                    } label: {
                                        sourceRow(source)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
        .presentationDetents(sources.isEmpty ? [.medium] : [.medium, .large])
    }

    private func sourceRow(_ source: MealCopying.Source) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(dayTitle(source.day))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                Text("\(source.meal.displayName) · \(source.itemCount) food\(source.itemCount == 1 ? "" : "s")")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            Text("\(NutritionRounding.caloriesText(source.calories)) kcal")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .appCard()
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

struct CopyToTodaySheet: View {
    let meal: MealType
    let itemCount: Int
    let calories: Double
    var onCopy: (MealType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeal: MealType

    init(meal: MealType, itemCount: Int, calories: Double, onCopy: @escaping (MealType) -> Void) {
        self.meal = meal
        self.itemCount = itemCount
        self.calories = calories
        self.onCopy = onCopy
        _selectedMeal = State(initialValue: meal)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(meal.displayName) · \(itemCount) food\(itemCount == 1 ? "" : "s")")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text("\(NutritionRounding.caloriesText(calories)) kcal")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add to today")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                        Picker("Meal", selection: $selectedMeal) {
                            ForEach(MealType.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Button("Copy to Today") {
                        onCopy(selectedMeal)
                        dismiss()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Copy Meal")
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
