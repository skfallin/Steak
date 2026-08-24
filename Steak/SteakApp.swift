import SwiftUI
import SwiftData

@main
struct SteakApp: App {
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
                .tint(.steakAccent)
                .preferredColorScheme(.dark)
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
    }
}
