# XEye iOS (MS1 Scaffold)

This directory contains the initial iOS implementation scaffold aligned with the migration plan.

## Current status

- Domain and game logic migrated (`Rarity`, `Category`, `XPFormula`, combo, category inference)
- Persistence layer implemented (`UserDefaultsProgressStore`, `JSONCollectionStore`)
- Inference boundary extracted (`InferenceServing`) with local Gemma Core ML primary + mock fallback
- Minimal SwiftUI flow implemented (`camera -> menu -> collection`)
- Basic unit tests added for core game logic
- Xcode project generation added (`project.yml` -> `XEyeApp.xcodeproj`)
- Live camera preview added via `AVFoundation` service

## Structure

- `Sources/App`: App entry point
- `Sources/Domain`: models and pure logic
- `Sources/Data`: persistence
- `Sources/Services`: camera and inference boundaries
- `Sources/ViewModels`: state and orchestration
- `Sources/UI`: SwiftUI screens
- `Tests`: unit tests

Note: current `Package.swift` builds the core layers (`Domain/Data/Services`) for `swift test`.
`App/UI/ViewModels` are scaffolded for Xcode app integration in the next step.

## Next implementation steps

1. Replace `CameraServicePlaceholder` with AVFoundation-based live camera service
2. Add `Gemma4Vision.mlmodelc` to app bundle for full local Gemma inference output
3. Wire camera frames into `CameraViewModel.submitFrame(_:)`
4. Implement diary/quests/achievements screens and logic parity
5. Add image thumbnail persistence and loading

## Run on real device

1. Generate project:
	- `cd ios/XEye`
	- `xcodegen generate`
2. Open project:
	- `open XEyeApp.xcodeproj`
3. In Xcode:
	- set your Team in `Signing & Capabilities`
	- choose your iPhone/iPad device
	- run target `XEyeApp`
4. Accept camera permission when prompted.

### One-command device build

- `cd ios/XEye`
- `./scripts/run_on_device.sh`

Optional environment variables:

- `DEVICE_ID=<your-udid>`: force a specific connected device
- `DEVELOPMENT_TEAM=<team-id>`: use explicit signing team for CLI build
- `PRODUCT_BUNDLE_IDENTIFIER=<id>`: override bundle id when provisioning requires a unique id

If script reports `pairing is in progress`, unlock the device and accept the trust dialog, then re-run.

CLI build check (already verified in this repo):
- `xcodebuild -project XEyeApp.xcodeproj -scheme XEyeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

## Gemma4 integration

- Current runtime uses `GemmaCoreMLInferenceService` first and falls back to `MockInferenceService` automatically.
- See detailed guide: `docs/gemma4-ios.md`
- For full Gemma4 local inference, bundle `Gemma4Vision.mlmodelc` in target `XEyeApp`.
