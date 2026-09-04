import SwiftUI
import SwiftData

struct HomeView: View {
    let onAddTapped: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var persistenceError: String?
    @State private var openEntryID: UUID?
    @State private var entryBeingEdited: FoodEntry?

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
            ZStack {
                AtmosphericBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.xxLarge) {
                        dailyHeader
                        ringCard
                        macroCard
                        mealsSection
                    }
                    .padding(.horizontal, Layout.xLarge)
                    .padding(.top, Layout.large)
                    .padding(.bottom, Layout.xxLarge)
                }
                .scrollBounceBehavior(.basedOnSize)
                .clipped()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Couldn't delete food", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "The food was not deleted. Please try again.")
        }
        .sheet(item: $entryBeingEdited) { entry in
            EditFoodEntrySheet(entry: entry)
        }
    }

    private var dailyHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("steak.")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(-3)
                    .foregroundStyle(Color.steakTint)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if !dynamicTypeSize.isAccessibilitySize {
                SteakIllustration()
                    .frame(width: 78)
                    .rotationEffect(.degrees(12))
            }
        }
    }

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: Layout.medium) {
            HStack {
                Text("Today's cut")
                    .font(.title.weight(.black))
                Spacer()
                Image(systemName: "fork.knife")
                    .font(.title3.weight(.heavy))
            }
            .foregroundStyle(.white)

            CalorieRing(consumed: consumed, goal: Double(profile?.dailyCalorieGoal ?? 2000))
                .frame(maxWidth: .infinity)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 218)

            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Layout.large) { dailyStats }
                } else {
                    HStack(spacing: Layout.medium) { dailyStats }
                }
            }
            .foregroundStyle(.white)
        }
        .padding(Layout.xLarge)
        .steakPanel(fill: .steakAccent, radius: 28, raised: true)
    }

    private var dailyStats: some View {
        Group {
            statLine(label: "Eaten", value: "\(consumed.kcalText)", icon: "fork.knife")
            statLine(label: "Goal", value: "\(profile?.dailyCalorieGoal ?? 2000)", icon: "target")
            statLine(label: "Foods", value: "\(todayEntries.count)", icon: "square.stack")
        }
    }

    private func statLine(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
            Text(value)
                .font(.title3.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var macroCard: some View {
        let goal = profile?.dailyCalorieGoal ?? 2000
        let targets = CalorieCalculator.macroTargets(totalCalories: goal)
        let t = totals

        return VStack(alignment: .leading, spacing: Layout.large) {
            HStack(alignment: .firstTextBaseline) {
                Text("The breakdown")
                    .font(.title3.weight(.black))
                Spacer()
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("Daily macros")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }

            VStack(spacing: Layout.medium) {
                MacroBar(label: "Protein", value: t.protein, target: targets.protein, color: Theme.proteinColor)
                MacroBar(label: "Carbs", value: t.carbs, target: targets.carbs, color: Theme.carbsColor)
                MacroBar(label: "Fat", value: t.fat, target: targets.fat, color: Theme.fatColor)
            }
        }
        .padding(Layout.xLarge)
        .steakPanel(radius: 20)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Layout.large) {
            HStack(alignment: .firstTextBaseline) {
                Text("Food log")
                    .font(.title2.weight(.black))
                Spacer()
                Text(todayEntries.isEmpty ? "No entries" : "\(todayEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

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
        VStack(spacing: Layout.medium) {
            SteakIllustration().frame(width: 96)
            Text("Your plate is empty")
                .font(.title3.weight(.heavy))
            Text("Scan a barcode or search for food to get started.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button(action: onAddTapped) {
                Label("Log food", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(SteakButtonStyle())
            .tint(.steakTint)
            .padding(.top, Layout.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.section)
        .padding(.horizontal, Layout.xxLarge)
        .steakPanel(fill: Theme.blush, radius: 20)
    }

    private func mealGroup(_ meal: MealType, entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Label(meal.label, systemImage: meal.icon)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Color.steakTint)
                .padding(.leading, 4)

            VStack(spacing: Layout.small) {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }
        }
    }

    private func entryRow(_ entry: FoodEntry) -> some View {
        FoodEntrySwipeRow(
            isOpen: openEntryID == entry.id,
            onOpen: { openEntryID = entry.id },
            onClose: { openEntryID = nil },
            onEdit: {
                openEntryID = nil
                entryBeingEdited = entry
            },
            onDelete: {
                openEntryID = nil
                delete(entry)
            }
        ) {
            entryCard(entry)
        }
    }

    private func entryCard(_ entry: FoodEntry) -> some View {
        HStack(spacing: Layout.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.bold))
                    .lineLimit(1)
                if !entry.brand.isEmpty {
                    Text(entry.brand)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Text(portionText(entry))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("\(entry.calories.kcalText)")
                .font(.headline.monospacedDigit())
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, Layout.large)
        .padding(.vertical, Layout.medium)
        .steakPanel(radius: 16)
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

private struct FoodEntrySwipeRow<Content: View>: View {
    private let revealWidth: CGFloat = 144

    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isHorizontalDrag: Bool?

    private var cardOffset: CGFloat {
        isHorizontalDrag == true ? dragOffset : (isOpen ? -revealWidth : 0)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons

            content()
                .offset(x: cardOffset)
                .accessibilityAction(named: Text("Edit")) {
                    onEdit()
                }
                .accessibilityAction(named: Text("Delete")) {
                    onDelete()
                }
                .simultaneousGesture(swipeGesture)
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.snappy, value: isOpen)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            actionButton(
                title: "Edit",
                icon: "pencil",
                color: .steakTint,
                action: onEdit
            )
            actionButton(
                title: "Delete",
                icon: "trash",
                color: .red,
                action: onDelete
            )
        }
        .frame(width: revealWidth, alignment: .trailing)
        .allowsHitTesting(isOpen)
        .accessibilityHidden(!isOpen)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(width: 68, height: 48)
            .background(color.opacity(0.28), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .accessibilityLabel(title)
        .accessibilityHint("\(title) this food entry")
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if isHorizontalDrag == nil {
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if horizontal > 4 || vertical > 4 {
                        isHorizontalDrag = horizontal > vertical
                    }
                }

                guard isHorizontalDrag == true else { return }
                let initialOffset = isOpen ? -revealWidth : 0
                dragOffset = min(0, max(-revealWidth, initialOffset + value.translation.width))
            }
            .onEnded { value in
                defer {
                    isHorizontalDrag = nil
                    dragOffset = 0
                }

                guard isHorizontalDrag == true else { return }
                let initialOffset = isOpen ? -revealWidth : 0
                let predictedOffset = min(
                    0,
                    max(-revealWidth, initialOffset + value.predictedEndTranslation.width)
                )
                if predictedOffset < -revealWidth / 2 {
                    onOpen()
                } else {
                    onClose()
                }
            }
    }
}
