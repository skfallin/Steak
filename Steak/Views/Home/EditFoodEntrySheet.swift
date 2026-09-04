import SwiftUI
import SwiftData

struct EditFoodEntrySheet: View {
    let entry: FoodEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let originalGrams: Double
    private let originalCalories: Double
    private let originalProtein: Double
    private let originalCarbs: Double
    private let originalFat: Double

    @State private var mealType: MealType
    @State private var gramsText: String
    @State private var saveError: String?

    init(entry: FoodEntry) {
        self.entry = entry
        originalGrams = entry.grams
        originalCalories = entry.calories
        originalProtein = entry.protein
        originalCarbs = entry.carbs
        originalFat = entry.fat
        _mealType = State(initialValue: entry.mealType)
        _gramsText = State(initialValue: String(entry.grams))
    }

    private var hasValidNutritionBaseline: Bool {
        NutritionSafety.isValidTotals(
            calories: originalCalories,
            protein: originalProtein,
            carbs: originalCarbs,
            fat: originalFat
        )
    }

    private var canEditGrams: Bool {
        entry.barcode != nil
            && NutritionSafety.isValidServingGrams(originalGrams)
            && hasValidNutritionBaseline
    }

    private var gramsUnavailableMessage: String {
        if entry.barcode == nil {
            return "Grams can only be edited for scanned entries."
        }
        if !NutritionSafety.isValidServingGrams(originalGrams) {
            return "Grams can't be edited because this entry has no valid original amount."
        }
        return "Grams can't be edited because this entry has invalid original nutrition."
    }

    private var grams: Double? {
        let trimmed = gramsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            return nil
        }
        return value
    }

    private var scaledNutrition: (calories: Double, protein: Double, carbs: Double, fat: Double)? {
        guard canEditGrams,
              let grams,
              NutritionSafety.isValidServingGrams(grams) else {
            return nil
        }

        let ratio = grams / originalGrams
        let values = (
            calories: originalCalories * ratio,
            protein: originalProtein * ratio,
            carbs: originalCarbs * ratio,
            fat: originalFat * ratio
        )
        return NutritionSafety.isValidTotals(
            calories: values.calories,
            protein: values.protein,
            carbs: values.carbs,
            fat: values.fat
        ) ? values : nil
    }

    private var canSave: Bool {
        let mealChanged = mealType != entry.mealType
        guard canEditGrams else { return mealChanged }
        guard let grams, NutritionSafety.isValidServingGrams(grams) else { return false }
        guard grams != originalGrams else { return mealChanged }
        return scaledNutrition != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(entry.name)
                    if !entry.brand.isEmpty {
                        Text(entry.brand)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Amount") {
                    if canEditGrams {
                        HStack {
                            Text("Grams")
                            Spacer()
                            TextField("0", text: $gramsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(gramsUnavailableMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Meal") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.label, systemImage: meal.icon).tag(meal)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .steakForm()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.light)
        .alert("Couldn't save food", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Check the meal and grams, then try again.")
        }
    }

    private func save() {
        let mealChanged = mealType != entry.mealType
        var gramsChanged = false
        var updatedNutrition: (calories: Double, protein: Double, carbs: Double, fat: Double)?

        if canEditGrams {
            guard let grams, NutritionSafety.isValidServingGrams(grams) else {
                saveError = "Enter a portion between 1 and 10,000 g."
                return
            }
            gramsChanged = grams != originalGrams
            if gramsChanged {
                guard let scaledNutrition else {
                    saveError = "This portion produces invalid nutrition values."
                    return
                }
                updatedNutrition = scaledNutrition
            }
        }

        guard mealChanged || gramsChanged else { return }

        entry.mealType = mealType
        if gramsChanged, let updatedNutrition, let grams {
            entry.grams = grams
            entry.calories = updatedNutrition.calories
            entry.protein = updatedNutrition.protein
            entry.carbs = updatedNutrition.carbs
            entry.fat = updatedNutrition.fat
            entry.servingLabel = ""
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Your food could not be saved. Please try again."
        }
    }
}
