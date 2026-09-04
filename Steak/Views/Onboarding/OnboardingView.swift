import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var name = ""
    @State private var sex: Sex = .male
    @State private var ageText = "25"
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: Goal = .maintain
    @State private var persistenceError: String?

    private let steps = 7

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, Layout.large)

                ScrollView {
                    switch step {
                    case 0: welcomeStep
                    case 1: nameStep
                    case 2: sexStep
                    case 3: ageStep
                    case 4: bodyStep
                    case 5: activityStep
                    default: planStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                navButtons
                    .padding(.horizontal, Layout.xxLarge)
                    .padding(.bottom, Layout.xxLarge)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: step)
        .alert("Couldn't save profile", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "Your profile was not saved. Please try again.")
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: Layout.xLarge) {
            Text("A little tracking. A lot of living.")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.muted)
                .padding(.top, 32)

            SteakIllustration()
                .frame(maxWidth: 260)
                .rotationEffect(.degrees(-8))
                .padding(.vertical, 16)

            Text("steak.")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .tracking(-5)
                .foregroundStyle(Color.steakAccent)

            Text("Track what you eat.\nHit your goals.")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
    }

    private var nameStep: some View {
        StepContainer(
            title: "What should we call you?",
            subtitle: nil
        ) {
            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .font(.title2.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(Layout.xLarge)
                .steakPanel(radius: 16)
        }
    }

    private var sexStep: some View {
        StepContainer(title: "Biological sex", subtitle: "Used to estimate your metabolism.") {
            HStack(spacing: Layout.medium) {
                ForEach(Sex.allCases) { option in
                    optionCard(option.label, selected: sex == option) { sex = option }
                }
            }
        }
    }

    private var ageStep: some View {
        StepContainer(title: "How old are you?", subtitle: nil) {
            numberField("Age", text: $ageText)
        }
    }

    private var bodyStep: some View {
        StepContainer(title: "Height & weight", subtitle: "We use this to calculate your calorie needs.") {
            VStack(spacing: Layout.medium) {
                Text("Kilograms & centimeters. Change units later in Profile.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                numberField("Weight (kg)", text: $weightText)
                numberField("Height (cm)", text: $heightText)
            }
        }
    }

    private var activityStep: some View {
        StepContainer(title: "Activity level", subtitle: "How much do you move?") {
            VStack(spacing: Layout.small) {
                ForEach(ActivityLevel.allCases) { level in
                    selectRow(
                        title: level.label,
                        detail: level.detail,
                        selected: activity == level
                    ) { activity = level }
                }
            }
        }
    }

    private var goalStep: some View {
        StepContainer(title: "What's the plan?", subtitle: nil) {
            VStack(spacing: Layout.small) {
                ForEach(Goal.allCases) { option in
                    selectRow(
                        title: option.label,
                        detail: deltaText(option),
                        selected: goal == option
                    ) { goal = option }
                }
            }
        }
    }

    private var planStep: some View {
        StepContainer(title: "Your daily target", subtitle: "Based on Mifflin-St Jeor. You can change this anytime.") {
            VStack(spacing: Layout.large) {
                Text("\(previewTarget)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("kcal / day")
                    .foregroundStyle(.secondary)

                VStack(spacing: Layout.small) {
                    summaryRow("Maintenance", value: "\(previewTDEE.kcalText) kcal")
                    summaryRow("Goal", value: goal.label)
                }
                .padding(Layout.large)
                .steakPanel(fill: Theme.blush, radius: 20)
            }
        }
    }

    // MARK: - Pieces

    private var background: some View {
        AtmosphericBackground()
    }

    private var progressBar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Theme.blush)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(steps))
                        .animation(reduceMotion ? nil : .smooth, value: step)
                }
        }
        .frame(height: 8)
        .padding(.horizontal, Layout.section)
    }

    private var navButtons: some View {
        Group {
            HStack(spacing: Layout.medium) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(SteakButtonStyle(prominent: false))
                    .accessibilityLabel("Previous step")
                }

                Button {
                    advance()
                } label: {
                    Text(step == steps - 1 ? "Start tracking" : (step == 0 ? "Build my food diary" : "Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(SteakButtonStyle())
                .tint(.steakAccent)
                .disabled(!canAdvance)
            }
        }
    }

    private func optionCard(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .steakPanel(fill: selected ? Theme.blush : .white, radius: 16)
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: Layout.mediumCornerRadius)
                            .strokeBorder(Theme.accentGradient, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func selectRow(title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.secondary))
            }
            .padding(Layout.large)
            .steakPanel(fill: selected ? Theme.blush : .white, radius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func numberField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)
            .font(.title2.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(Layout.xLarge)
            .steakPanel(radius: 16)
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Logic

    private var previewProfile: UserProfile {
        let p = UserProfile()
        p.sex = sex
        p.age = Int(ageText) ?? 25
        p.heightCm = Units.parseHeightToCm(heightText, system: .metric) ?? 175
        p.weightKg = Units.parseWeightToKg(weightText, system: .metric) ?? 70
        p.activity = activity
        p.goal = goal
        return p
    }

    private var previewTDEE: Double {
        let value = CalorieCalculator.tdee(profile: previewProfile)
        return value.isFinite ? value : 0
    }
    private var previewTarget: Int { CalorieCalculator.dailyTarget(for: previewProfile) }

    private var canAdvance: Bool {
        switch step {
        case 1: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        case 3: return Int(ageText).map { (5...120).contains($0) } ?? false
        case 4:
            return (Units.parseWeightToKg(weightText, system: .metric).map { (25..<500).contains($0) } ?? false)
                && (Units.parseHeightToCm(heightText, system: .metric).map { (80..<260).contains($0) } ?? false)
        default: return true
        }
    }

    private func deltaText(_ goal: Goal) -> String {
        switch goal {
        case .lose: return "−500 kcal per day"
        case .maintain: return "Stay at maintenance"
        case .gain: return "+300 kcal per day"
        }
    }

    private func advance() {
        if step < steps - 1 {
            withAnimation { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        let profile = previewProfile
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.units = .metric
        profile.hasCompletedOnboarding = true
        modelContext.insert(profile)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = "Your profile was not saved. Please try again."
        }
    }
}

private struct StepContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: Layout.xxLarge) {
            Spacer(minLength: Layout.xxLarge)
            VStack(spacing: Layout.small) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            content
                .padding(.horizontal, Layout.largeCornerRadius)
            Spacer(minLength: Layout.xxLarge)
        }
    }
}
