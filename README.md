# Steak

<p align="center">
  <img src="Steak/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Steak app icon" width="128" />
</p>

<p align="center"><strong>Track what you eat. Hit your goals.</strong></p>

Steak is an iPhone food journal for logging meals from product barcodes, Open Food Facts searches, or manual entries. Its source is available under a noncommercial license; it is not OSI-approved open source software.

## Features

- Barcode scanning focused on GTIN product codes: EAN-8, EAN-13, UPC-E, ITF-14, and GS1 DataBar.
- Explicit, submit-to-search Open Food Facts lookup with a local request guard that respects the documented search rate guidance.
- Manual food logging, serving-size suggestions, meal grouping, calorie progress, and macro summaries.
- A local SwiftData profile with metric and imperial display options.

Generic QR codes and internal store codes are intentionally unsupported because they are not reliable product identifiers.

## Privacy

Steak stores your profile and food history locally on your device. When you submit a typed search or scan a product code, that query or code is sent to Open Food Facts along with ordinary network metadata such as your IP address and the app User-Agent. Camera frames, your profile, and app logs remain local to the device.

## Requirements

- macOS with Xcode 26.6 or later
- iOS 26.0 SDK; iPhone target
- An Apple ID or Apple Developer team for device signing

## Build from source

```sh
git clone https://github.com/skfallin/Steak.git
cd Steak
open Steak.xcodeproj
```

In Xcode, select the `Steak` target, choose your own signing team, select an iPhone simulator or device, and build. Contributors must provide their own signing team; no development team is committed to this project.

For an unsigned command-line Simulator build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Steak.xcodeproj \
  -scheme Steak \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Architecture

```text
Steak/
├── Models/       SwiftData models for profiles and food entries
├── Services/     calorie calculations and Open Food Facts client
├── Shared/       theme, unit display, and common helpers
├── Views/        onboarding, Home, Add/scanner, and Profile flows
└── Assets.xcassets/
```

## Open Food Facts attribution and data license

Product data is provided by [Open Food Facts](https://world.openfoodfacts.org), a collaborative, community-maintained food database. Open Food Facts database contents are available under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/); individual database contents are available under the [Database Contents License](https://opendatacommons.org/licenses/dbcl/). See Open Food Facts’ [license guidance](https://world.openfoodfacts.org/data) for the current attribution and reuse terms.

## Health disclaimer

Steak helps you record food information; it is not medical advice. Nutrition targets and estimates may be incomplete or inaccurate. Consult a qualified health professional for medical, dietary, or treatment decisions.

## Contributing

Contributions are welcome for noncommercial use. By submitting a contribution, you agree to license it under the same PolyForm Noncommercial License 1.0.0 that applies to this repository. Please keep changes focused, add validation where practical, and do not include secrets, signing material, or generated build output.

## License and commercial use

Steak is source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE). Commercial use is prohibited unless you receive separate permission from the copyright holder. The required copyright notice appears in [NOTICE](NOTICE).

The repository owner must confirm that they have the rights needed to publish all included assets, including the app icon, before making the repository public.
