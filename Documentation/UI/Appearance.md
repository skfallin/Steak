# Appearance settings

Profile > Appearance > Theme provides Light, Dark and System. System is the default and follows device changes while the app is running. The selection persists in UserDefaults through AppStorage, independently of the SwiftData profile.

The dynamic palette keeps the light design's original colors. Dark mode uses burgundy backgrounds, warm cream text, salmon foreground accents and muted red outlines. Red button/hero backgrounds and the white meat illustration remain fixed so their text and artwork keep the intended contrast. Sheets inherit the app's appearance; their former Light overrides were removed.

## Files

- `Steak/Shared/AppAppearance.swift`: persisted preference values and optional ColorScheme mapping.
- `Steak/SteakApp.swift`: app-wide appearance and adaptive tint.
- `Steak/Shared/GlassStyle.swift`: dynamic surfaces, foregrounds, outlines, shadows and buttons.
- `Steak/Views/Profile/ProfileView.swift`: accessible native theme picker.
- Home, CalorieRing, Add and Onboarding views: separate fixed illustration colors from adaptive UI colors.
- ManualFoodForm, PortionPickerSheet and EditFoodEntrySheet: inherit appearance from the presentation.

## Verification

- PASS: Xcode 26.6 Debug simulator build, no compile errors; existing App Intents metadata notice only.
- PASS: Light, Dark and System selected through the app UI on an iPhone 17e simulator, iOS 26.5.
- PASS: Dark selection retained after app termination and relaunch while the device uses Light.
- PASS: Light overrides a Dark device setting.
- PASS: Switching Light to System restores the Dark device setting immediately.
- PASS: System follows a subsequent device switch back to Light without restarting the app.
- PASS: Home, Profile and manual-entry sheet inspected in Dark mode.
- PASS: dark palette contrast: cream/surface 15.17:1, muted/surface 7.82:1, muted/blush 6.71:1, accent/background 6.94:1, accent/blush 5.18:1, fat/blush 6.63:1.
- PASS: `git diff --check` and `graphify update .`.

No dependencies or database migration added. Testing used the existing isolated review simulator and its clearly synthetic food data. Screenshots: `appearance-dark.png`, `home-dark.png`, `appearance-system-light.png`.
