import SwiftUI
import SwiftData

@main
struct SteakApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: UserProfile.self, FoodEntry.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tint(.steakTint)
                .preferredColorScheme(appearance.colorScheme)
                .fontDesign(.rounded)
                .foregroundStyle(Theme.ink)
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var didSeed = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        if let profile, profile.hasCompletedOnboarding {
            MainTabView(profile: profile)
        } else {
            OnboardingView()
                .onAppear { seedUITestDataIfRequested() }
        }
    }

    /// DEBUG-only: `-uitest-seed` skips onboarding with sample data.
    private func seedUITestDataIfRequested() {
        guard !didSeed,
              ProcessInfo.processInfo.arguments.contains("-uitest-seed"),
              profiles.isEmpty else { return }
        didSeed = true

        let profile = UserProfile()
        profile.name = "Fra"
        profile.sex = .male
        profile.age = 30
        profile.heightCm = 180
        profile.weightKg = 75
        profile.activity = .moderate
        profile.goal = .maintain
        profile.hasCompletedOnboarding = true
        modelContext.insert(profile)

        let samples: [(String, String, Double, Double, Double, Double, MealType)] = [
            ("Greek Yogurt", "Chobani", 130, 16, 6, 3, .breakfast),
            ("Chicken Bowl", "Chipotle", 630, 55, 65, 18, .lunch),
            ("Nutella", "Ferrero", 269, 5, 29, 15, .snack),
        ]
        for (name, brand, kcal, p, c, f, meal) in samples {
            modelContext.insert(FoodEntry(
                name: name, brand: brand, barcode: nil,
                calories: kcal, protein: p, carbs: c, fat: f,
                grams: 100, mealType: meal
            ))
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            assertionFailure("Failed to seed UI test data: \(error.localizedDescription)")
        }
    }
}

enum AppTab: Hashable {
    case home, add, profile
}

struct MainTabView: View {
    let profile: UserProfile
    @State private var selection: AppTab = MainTabView.initialTab()

    private static func initialTab() -> AppTab {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest-tab-add") { return .add }
        if args.contains("-uitest-tab-profile") { return .profile }
        return .home
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(onAddTapped: { selection = .add })
                .tabItem { Label("Home", systemImage: "flame.fill") }
                .tag(AppTab.home)

            AddView()
                .tabItem { Label("Add", systemImage: "plus") }
                .tag(AppTab.add)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                tabButton(.home, title: "Diary", icon: "fork.knife")
                tabButton(.add, title: "Add food", icon: "plus")
                tabButton(.profile, title: "Profile", icon: "person.crop.circle")
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Theme.paper)
            .overlay(alignment: .top) { Rectangle().fill(Theme.outline).frame(height: 2) }
        }
    }

    private func tabButton(_ tab: AppTab, title: String, icon: String) -> some View {
        Button { selection = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3.weight(.heavy))
                Text(title).font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(selection == tab ? Color.white : Theme.ink)
            .background(selection == tab ? Color.steakAccent : .clear, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
