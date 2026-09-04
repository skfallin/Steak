import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Query private var profiles: [UserProfile]
    @Query private var allEntries: [FoodEntry]

    @State private var showResetConfirm = false
    @State private var showWipeConfirm = false
    @State private var persistenceError: String?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphericBackground()

                Group {
                    if let profile {
                        content(profile)
                    } else {
                        ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.questionmark")
                    }
                }
            }
            .navigationTitle("Your recipe")
            .tint(.steakTint)
        }
    }

    private func content(_ profile: UserProfile) -> some View {
        Form {
            Section {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name.isEmpty ? "Your profile" : profile.name)
                            .font(.largeTitle.weight(.black))
                        Text("Your body. Your goals.")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    SteakIllustration().frame(width: 90).rotationEffect(.degrees(10))
                }
                .padding(.vertical, 14)
            }
            .listRowBackground(Color.steakAccent)
            appearanceSection
            profileSection(profile)
            planSection(profile)
            unitsSection(profile)
            dataSection
            aboutSection
        }
        .steakForm()
        .contentMargins(.top, Layout.small, for: .scrollContent)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Appearance")
        } footer: {
            Text("System follows your device's appearance.")
        }
    }

    private func profileSection(_ profile: UserProfile) -> some View {
        Section("Profile") {
            HStack {
                Text("Name")
                Spacer()
                TextField("Name", text: persistedBinding(profile, keyPath: \.name))
                    .multilineTextAlignment(.trailing)
            }

            Picker("Sex", selection: persistedBinding(profile, keyPath: \.sex)) {
                ForEach(Sex.allCases) { sex in
                    Text(sex.label).tag(sex)
                }
            }

            Stepper(value: persistedBinding(profile, keyPath: \.age), in: 5...120) {
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(profile.age)")
                        .foregroundStyle(Theme.muted)
                }
            }

            unitAwareField(
                label: "Height",
                value: profile.heightCm,
                display: { Units.displayHeight(cm: $0, system: profile.units) },
                placeholder: Units.heightPlaceholder(system: profile.units),
                commit: { text in
                    if let cm = Units.parseHeightToCm(text, system: profile.units), (80..<260).contains(cm) {
                        updateProfile(profile, keyPath: \.heightCm, value: cm)
                    }
                }
            )

            unitAwareField(
                label: "Weight",
                value: profile.weightKg,
                display: { Units.displayWeight(kg: $0, system: profile.units) },
                placeholder: Units.weightPlaceholder(system: profile.units),
                commit: { text in
                    if let kg = Units.parseWeightToKg(text, system: profile.units), (25..<500).contains(kg) {
                        updateProfile(profile, keyPath: \.weightKg, value: kg)
                    }
                }
            )
        }
    }

    private func planSection(_ profile: UserProfile) -> some View {
        Section("Plan") {
            Picker("Activity", selection: persistedBinding(profile, keyPath: \.activity)) {
                ForEach(ActivityLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }

            Picker("Goal", selection: persistedBinding(profile, keyPath: \.goal)) {
                ForEach(Goal.allCases) { goal in
                    Text(goal.label).tag(goal)
                }
            }

            LabeledContent("Maintenance") {
                Text("\(CalorieCalculator.tdee(profile: profile).kcalText) kcal")
                    .foregroundStyle(Theme.muted)
            }

            Toggle("Custom daily target", isOn: Binding(
                get: { profile.manualCalorieGoal != nil },
                set: { on in
                    updateProfile(
                        profile,
                        keyPath: \.manualCalorieGoal,
                        value: on ? CalorieCalculator.dailyTarget(for: profile) : nil
                    )
                }
            ))

            if let manual = profile.manualCalorieGoal {
                Stepper(value: Binding(
                    get: { manual },
                    set: {
                        updateProfile(
                            profile,
                            keyPath: \.manualCalorieGoal,
                            value: max(1000, min(6000, $0))
                        )
                    }
                ), in: 1000...6000, step: 50) {
                    HStack {
                        Text("Daily target")
                        Spacer()
                        Text("\(manual) kcal")
                            .foregroundStyle(Theme.muted)
                    }
                }
            } else {
                LabeledContent("Daily target") {
                    Text("\(profile.dailyCalorieGoal) kcal")
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func unitsSection(_ profile: UserProfile) -> some View {
        Section("Units") {
            Picker("Measurement", selection: persistedBinding(profile, keyPath: \.units)) {
                ForEach(UnitsSystem.allCases) { system in
                    Text(system.label).tag(system)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var dataSection: some View {
        Section("Data") {
            LabeledContent("Logged foods") {
                Text("\(allEntries.count)")
                    .foregroundStyle(Theme.muted)
            }

            Button(role: .destructive) {
                showWipeConfirm = true
            } label: {
                Text("Delete all logged foods")
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text("Reset app & redo onboarding")
            }
        }
        .confirmationDialog(
            "Delete every logged food?",
            isPresented: $showWipeConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) { wipeEntries() }
        } message: {
            Text("This removes your entire food history. Your profile stays.")
        }
        .confirmationDialog(
            "Reset the app?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset everything", role: .destructive) { resetAll() }
        } message: {
            Text("Your profile and history will be erased and onboarding starts again.")
        }
        .alert("Couldn't update data", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "Your data was not changed. Please try again.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersion).foregroundStyle(Theme.muted)
            }
            LabeledContent("Food data") {
                Link("Open Food Facts", destination: URL(string: "https://world.openfoodfacts.org")!)
            }
        }
    }

    // MARK: - Helpers

    private func unitAwareField(
        label: String,
        value: Double,
        display: @escaping (Double) -> String,
        placeholder: String,
        commit: @escaping (String) -> Void
    ) -> some View {
        UnitAwareNumberField(
            label: label,
            value: value,
            display: display,
            commit: commit
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }

    private func persistedBinding<Value>(
        _ profile: UserProfile,
        keyPath: ReferenceWritableKeyPath<UserProfile, Value>
    ) -> Binding<Value> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { updateProfile(profile, keyPath: keyPath, value: $0) }
        )
    }

    private func updateProfile<Value>(
        _ profile: UserProfile,
        keyPath: ReferenceWritableKeyPath<UserProfile, Value>,
        value: Value
    ) {
        profile[keyPath: keyPath] = value
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = "Your profile change was not saved. Please try again."
        }
    }

    private func wipeEntries() {
        for entry in allEntries {
            modelContext.delete(entry)
        }
        saveChangesOrRollback()
    }

    private func resetAll() {
        for entry in allEntries {
            modelContext.delete(entry)
        }
        for p in profiles {
            modelContext.delete(p)
        }
        saveChangesOrRollback()
    }

    private func saveChangesOrRollback() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = "Your data was not changed. Please try again."
        }
    }
}

extension View {
    /// Simple placeholder overlay for plain TextFields.
    @ViewBuilder
    func placeholder(when condition: Bool, @ViewBuilder content: () -> some View) -> some View {
        overlay(alignment: .trailing) {
            if condition { content().allowsHitTesting(false) }
        }
    }
}

/// Numeric field that shows the current value in the user's units and
/// commits an edited value when submitted.
private struct UnitAwareNumberField: View {
    let label: String
    let value: Double
    let display: (Double) -> String
    let commit: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if isEditing {
                TextField("", text: $draft)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .frame(width: 110)
                    .onSubmit(submit)
                    .submitLabel(.done)
            } else {
                Button {
                    draft = ""
                    isEditing = true
                    focused = true
                } label: {
                    Text(display(value))
                        .foregroundStyle(Theme.muted)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(label)")
                .accessibilityValue(display(value))
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused && isEditing { submit() }
        }
    }

    private func submit() {
        commit(draft)
        isEditing = false
        draft = ""
    }
}
