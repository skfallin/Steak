import SwiftUI
import SwiftData

struct ManualFoodForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var amountText = ""
    @State private var kcalText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var mealType: MealType = MealType.suggested()
    @State private var saveError: String?

    private var draft: ManualDraft? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 160, trimmedBrand.count <= 160,
              let calories = parseRequired(kcalText),
              let protein = parseOptional(proteinText),
              let carbs = parseOptional(carbsText),
              let fat = parseOptional(fatText),
              let grams = parseOptional(amountText),
              NutritionSafety.isValidTotals(calories: calories, protein: protein, carbs: carbs, fat: fat),
              amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || NutritionSafety.isValidServingGrams(grams) else {
            return nil
        }
        return ManualDraft(
            name: trimmedName,
            brand: trimmedBrand,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            grams: grams
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }

                Section("Amount") {
                    TextField("Grams eaten (optional)", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Nutrition for this amount") {
                    nutritionRow("Calories", text: $kcalText, suffix: "kcal")
                    nutritionRow("Protein", text: $proteinText, suffix: "g")
                    nutritionRow("Carbs", text: $carbsText, suffix: "g")
                    nutritionRow("Fat", text: $fatText, suffix: "g")
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
            .navigationTitle("New food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addEntry() }
                        .font(.body.weight(.semibold))
                        .disabled(draft == nil)
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
            Text(saveError ?? "Check the amount and nutrition values, then try again.")
        }
    }

    private func nutritionRow(_ label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }

    private func parseRequired(_ text: String) -> Double? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return parseOptional(text)
    }

    private func parseOptional(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            return nil
        }
        return value
    }

    private func addEntry() {
        guard let draft else {
            saveError = "Enter a name and finite, nonnegative nutrition values. Portions must be between 1 and 10,000 g."
            return
        }

        let entry = FoodEntry(
            name: draft.name,
            brand: draft.brand,
            barcode: nil,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
            grams: draft.grams,
            servingLabel: "",
            mealType: mealType
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Your food could not be saved. Please try again."
        }
    }
}

private struct ManualDraft {
    let name: String
    let brand: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let grams: Double
}
