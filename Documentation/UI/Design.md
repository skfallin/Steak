# Steak UI redesign

## Direction

User brief: maximalist, cartoon-like, red and white, related to the cut of meat in the existing app icon. Antislop was applied during implementation, as requested, without changing project instructions or installing skills.

ENERGY 3 / RHYTHM 2 / MOTION 1. A bold food diary for daily use, with a large calorie focal point, quieter nutrition rows, and restrained interaction feedback.

## Decisions

- Deep meat red and warm white translate the existing icon into legible interface colors.
- Burgundy outlines and solid offset shadows make the hero and primary actions read like physical stickers.
- Rounded heavy system typography gives the cartoon character a native, readable voice without adding a font dependency.
- The asymmetrical steak silhouette replaces the generic calorie ring; its outline still tracks real progress.
- Marbling is drawn with SwiftUI paths, derived from the user's requested meat motif. The original app icon is unchanged.
- The cream light theme and burgundy dark theme share the same geometry. Profile > Appearance > Theme offers Light, Dark and System; System is the default. The red-and-white meat illustration keeps its fixed colors in both appearances.
- Red is concentrated in the calorie summary, brand, selected navigation and primary actions; details sit on cream or white.
- Forms retain native editing, validation and pickers. Onboarding no longer shows an inert imperial-unit toggle; its metric behavior is stated explicitly, with units editable later in Profile.
- Navigation labels cap at XXXL to keep all three destinations available. At accessibility text sizes, the calorie summary and macro labels switch to vertical layouts rather than squeeze inside illustration geometry.
- New button and progress animations respect Reduce Motion. No ornamental continuous animation was added.

## References and documentation

Lazyweb searches: `calorie tracker food diary`, `food diary dashboard`, mobile. The latter returned strong coverage (0.649 top similarity), with MyFitnessPal and Lose It references describing a calorie-first hierarchy and accessible log/add navigation. These informed content priority, not the visual style. No external report was requested or published.

Framework: Swift 6, SwiftUI, deployment target iOS 26.0; built with Xcode 26.6, simulated on iOS 26.5. Context7 supplied Apple's Shape/Path documentation: https://developer.apple.com/documentation/swiftui/shape/path(in:).

## Verification

- PASS: Debug simulator build using `xcodebuild`, no Swift compile errors.
- PASS: `git diff --check`.
- PASS: Graphify AST graph updated with `graphify update .`.
- PASS: Home inspected on iPhone 17 Pro and iPhone 17e, including empty and populated diary states.
- PASS: Maximum accessibility text size inspected on iPhone 17e; the discovered calorie-label collision was corrected with an adaptive layout.
- PASS: Diary, Add food and Profile destinations exercised through the simulator UI.
- PASS: Search panel expands/collapses; manual entry opens; Escape dismisses a sheet.
- PASS: Manual test entry saved, increasing consumption from 1,029 to 4,129 kcal and displaying 1,447 kcal over a 2,682 target.
- PASS: Editing an entry's meal from Breakfast to Lunch persists and updates its grouping.
- PASS: Camera-denied and simulator-unavailable states inspected; manual entry remains available.
- PASS: Core text pairs measured in sRGB: ink/paper 15.05:1, ink/blush 12.03:1, muted/paper 6.85:1, muted/white 7.42:1, white/red 5.59:1, red/paper 5.16:1.
- PASS: No dependency added; models and service calculation/network logic unchanged.
- NOT VERIFIED: Physical barcode capture and torch, live product lookup/portion save, all destructive actions, complete VoiceOver/hardware-keyboard traversal, and every screen at every text size. This is not a claim of exhaustive accessibility certification.

The repository has no test target, formatter configuration or linter task. Xcode reports existing app-icon catalog warnings on a clean build and an App Intents metadata notice; these do not prevent compilation.

## Antislop delivery review

- PASS R-02/R-16: no em-dash copy or generic AI marketing claims introduced.
- PASS R-17/R-18/R-36/R-38: UI totals come from stored data; no social proof or statistics fabricated. Screenshots with foods use the existing debug seed in a dedicated simulator and are test illustrations, not user nutrition records.
- PASS R-20/R-23/R-30/R-31: the user's meat-icon direction is implemented with explicit palette, typography, layout and illustration reasons above; no other product's aesthetic is copied.
- PASS R-24/R-26: the three navigation items target existing screens; new controls have actions; the inert onboarding unit selector was removed.
- PASS R-25: explicit brand text colors pass AA in the measured pairs above. Native system placeholder/disabled styling remains native.
- PASS R-27: empty diary, search loading/error, save alerts, permission denial and scanner failure branches are retained.
- PASS R-33/R-34: UI changes were authored directly in Swift; the fixed light theme is consistent across sheets.
- PASS R-35 (build/run portion): simulator build and visible app operation verified. Exhaustive interaction coverage remains NOT VERIFIED as listed above.
- PASS purpose/liveliness: bold focal calorie cut, marbled motif, outlined controls, varied content hierarchy, and explicit dials give the product a specific identity.
- NOT VERIFIED R-03/R-32 full coverage: representative phone sizes, maximum-text Home and sheet dismissal were exercised; exhaustive breakpoints and keyboard traversal were not.

## Screenshots

- `home-empty.png`: final build on iPhone 17 Pro with the existing empty diary.
- `home.png`: standard Home, debug sample foods.
- `onboarding.png`: fresh onboarding, no sample profile.
- `home-accessibility.png`: maximum accessibility text, debug sample foods.
- `diary.png`: food groups after editing a sample entry.
- `scanner.png`: denied camera state, search/manual entry still available.
- `profile.png`: profile in the shared red/cream language.

## Changed source files

`Steak/Shared/GlassStyle.swift`, `Steak/SteakApp.swift`, `Steak/Views/Home/HomeView.swift`, `Steak/Views/Home/CalorieRing.swift`, `Steak/Views/Home/EditFoodEntrySheet.swift`, `Steak/Views/Add/AddView.swift`, `Steak/Views/Add/ManualFoodForm.swift`, `Steak/Views/Add/PortionPickerSheet.swift`, `Steak/Views/Onboarding/OnboardingView.swift`, `Steak/Views/Profile/ProfileView.swift`.

The pre-existing uncommitted view changes and edit-entry implementation were retained. The dedicated `Steak UI Review` simulator was shut down after verification; the main iPhone 17 Pro simulator has the final build open. No commit or push was made.
