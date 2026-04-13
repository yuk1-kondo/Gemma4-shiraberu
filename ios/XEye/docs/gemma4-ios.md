# Gemma4 on iOS: Integration Guide

This project now uses a local-first inference chain:

- `GemmaCoreMLInferenceService` (primary, on-device Core ML)
- `MockInferenceService` (fallback when Gemma model is unavailable)

At app startup, `InferenceServiceFactory.makeDefault()` tries Gemma first and falls back automatically.

## Path A (recommended): Core ML compiled model

1. Prepare a Gemma4-compatible iOS model artifact.
   - Target artifact in app bundle: `Gemma4Vision.mlmodelc`
2. Add model to Xcode target `XEyeApp` (Copy Bundle Resources).
3. Place the model at runtime path expected by the app:
   - in Xcode: `XEyeApp` target -> Build Phases -> Copy Bundle Resources
   - file name must be exactly `Gemma4Vision.mlmodelc`
4. (Optional but recommended) Add tokenizer vocab JSON for token-id decode:
   - file name: `gemma_vocab.json`
   - format: `{ "<token>": 123, ... }`
5. Launch app and verify camera examine result is produced without network.

## Path B: Hybrid fallback (recommended during development)

1. Keep `MockInferenceService` as fallback.
2. Try Gemma4 service first at startup.
3. If model load fails, app shows warning text and keeps local fallback active.

## Suggested service contract

- input: `CGImage`
- output: `InferenceResult(text: String)`
- errors: `modelNotReady`, `runtimeFailure(String)`

## Current implementation status

- Implemented in `Sources/App/GemmaCoreMLInferenceService.swift`
- Token decoder in `Sources/App/GemmaTokenDecoder.swift`
- Local decoding supports:
   - `VNClassificationObservation` (top label + confidence)
   - `VNCoreMLFeatureValueObservation` string output
   - token-id `MLMultiArray` -> text decode (when `gemma_vocab.json` is bundled)
   - multi-array numeric summary fallback for debugging output shape
- If primary inference throws at runtime, fallback service handles the request.

## Performance targets for MS1

- average inference latency: <= 1.5s
- no crash for 50 consecutive examines
- memory footprint stable during repeated capture

## Validation checklist

1. model file exists in app bundle
2. `loadModel()` reports ready state
3. `Examine` processes live camera frame (not placeholder)
4. text output persists into collection store
