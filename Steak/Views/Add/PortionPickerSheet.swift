import SwiftUI
import SwiftData

struct PortionPickerSheet: View {
    let product: OFFProduct

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var gramsText: String = ""
    @State private var mealType: MealType = MealType.suggested()
    @State private var saveError: String?

    private var grams: Double? {
        let trimmed = gramsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            return nil
        }
        return value
    }

    private var scaled: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        guard let grams, NutritionSafety.isValidServingGrams(grams) else {
            return (0, 0, 0, 0)
        }
        let values = product.scaled(grams: grams)
        return NutritionSafety.isValidTotals(
            calories: values.calories,
            protein: values.protein,
            carbs: values.carbs,
            fat: values.fat
        ) ? values : (0, 0, 0, 0)
    }

    private var isValidEntry: Bool {
        guard let grams, NutritionSafety.isValidServingGrams(grams), product.hasNutrition else { return false }
        let values = product.scaled(grams: grams)
        return NutritionSafety.isValidTotals(
            calories: values.calories,
            protein: values.protein,
            carbs: values.carbs,
            fat: values.fat
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    VStack(spacing: 14) {
                        HStack {
                            Text("Amount")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("100", text: $gramsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.title3.weight(.semibold).monospacedDigit())
                                .frame(width: 90)
                            Text("g")
                                .foregroundStyle(.secondary)
                        }

                        if let serving = product.servingQuantityGrams, NutritionSafety.isValidServingGrams(serving) {
                            Button {
                                gramsText = serving.gramsText
                            } label: {
                                Label(
                                    "1 serving (\(serving.gramsText) g)",
                                    systemImage: "arrow.uturn.backward.circle"
                                )
                                .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(18)
                    .steakPanel(radius: 20)

                    previewCard

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.label, systemImage: meal.icon).tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)

                    addButton
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.paper)
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            let initial = product.servingQuantityGrams.flatMap { NutritionSafety.isValidServingGrams($0) ? $0 : nil } ?? 100
            gramsText = initial.gramsText
        }
        .alert("Couldn't save food", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Check the portion and nutrition values, then try again.")
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(product.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            if !product.brand.isEmpty {
                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var previewCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(scaled.calories.kcalText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("kcal")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .animation(.smooth, value: scaled.calories)

            HStack(spacing: 0) {
                macroPill("P", value: scaled.protein, color: Theme.proteinColor)
                macroPill("C", value: scaled.carbs, color: Theme.carbsColor)
                macroPill("F", value: scaled.fat, color: Theme.fatColor)
            }
        }
        .padding(18)
        .steakPanel(fill: Theme.blush, radius: 20)
    }

    private func macroPill(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text("\(value.gramsText) g")
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private var addButton: some View {
        Button(action: addEntry) {
            Label("Add to \(mealType.label)", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(SteakButtonStyle())
        .disabled(!isValidEntry)
    }

    private func addEntry() {
        guard let grams, NutritionSafety.isValidServingGrams(grams) else {
            saveError = "Enter a portion between 1 and 10,000 g."
            return
        }
        let values = product.scaled(grams: grams)
        guard NutritionSafety.isValidTotals(
            calories: values.calories,
            protein: values.protein,
            carbs: values.carbs,
            fat: values.fat
        ) else {
            saveError = "This product's nutrition values are not safe to save."
            return
        }

        let entry = FoodEntry(
            name: product.name,
            brand: product.brand,
            barcode: product.barcode.isEmpty ? nil : product.barcode,
            calories: values.calories,
            protein: values.protein,
            carbs: values.carbs,
            fat: values.fat,
            grams: grams,
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
