import SwiftUI
import SwiftData

struct HomeView: View {
    let onAddTapped: () -> Void

    @State private var persistenceError: String?

    @Query(sort: \FoodEntry.createdAt, order: .reverse)
    private var allEntries: [FoodEntry]

    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var todayEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.day) }
    }

    private var consumed: Double {
        finiteSum(todayEntries.map(\.calories))
    }

    private var totals: (protein: Double, carbs: Double, fat: Double) {
        (
            finiteSum(todayEntries.map(\.protein)),
            finiteSum(todayEntries.map(\.carbs)),
            finiteSum(todayEntries.map(\.fat))
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ringCard
                    macroCard
                    mealsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddTapped) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .alert("Couldn't delete food", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "The food was not deleted. Please try again.")
        }
    }

    private var ringCard: some View {
        HStack(spacing: 24) {
            CalorieRing(consumed: consumed, goal: Double(profile?.dailyCalorieGoal ?? 2000))
                .frame(width: 170, height: 170)

            VStack(alignment: .leading, spacing: 14) {
                statLine(label: "Eaten", value: "\(consumed.kcalText)", icon: "fork.knife")
                statLine(
                    label: "Goal",
                    value: "\(profile?.dailyCalorieGoal ?? 2000)",
                    icon: "target"
                )
                statLine(
                    label: "Meals",
                    value: "\(todayEntries.count)",
                    icon: "square.stack"
                )
            }
        }
        .padding(22)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
    }

    private func statLine(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
    }

    private var macroCard: some View {
        let goal = profile?.dailyCalorieGoal ?? 2000
        let targets = CalorieCalculator.macroTargets(totalCalories: goal)
        let t = totals

        return VStack(spacing: 16) {
            MacroBar(label: "Protein", value: t.protein, target: targets.protein, color: Theme.proteinColor)
            MacroBar(label: "Carbs", value: t.carbs, target: targets.carbs, color: Theme.carbsColor)
            MacroBar(label: "Fat", value: t.fat, target: targets.fat, color: Theme.fatColor)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)
                .padding(.leading, 6)

            if todayEntries.isEmpty {
                emptyState
            } else {
                ForEach(MealType.allCases, id: \.self) { meal in
                    let entries = todayEntries.filter { $0.mealType == meal }
                        .sorted { $0.createdAt > $1.createdAt }
                    if !entries.isEmpty {
                        mealGroup(meal, entries: entries)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Nothing logged yet")
                .font(.subheadline.weight(.medium))
            Text("Scan a barcode or search for food to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func mealGroup(_ meal: MealType, entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(meal.label, systemImage: meal.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }
        }
    }

    private func entryRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !entry.brand.isEmpty {
                    Text(entry.brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(portionText(entry))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(entry.calories.kcalText)")
                .font(.headline.monospacedDigit())
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .contextMenu {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func portionText(_ entry: FoodEntry) -> String {
        if !entry.servingLabel.isEmpty {
            return entry.servingLabel
        }
        return "\(entry.grams.gramsText) g"
    }

    private func delete(_ entry: FoodEntry) {
        guard let context = entry.modelContext else { return }
        context.delete(entry)
        do {
            try context.save()
        } catch {
            context.rollback()
            persistenceError = "The food was not deleted. Please try again."
        }
    }

    private func finiteSum(_ values: [Double]) -> Double {
        let total = values.reduce(0, +)
        return total.isFinite ? total : 0
    }
}
