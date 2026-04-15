# LiteRT iOS Runtime Bridge

This app now supports loading a LiteRT runtime bridge dynamically at startup.

## What is implemented

- `LiteRTInferenceService` searches model files:
  - `gemma4.litertlm`
  - `gemma4e2b.litertlm`
- Search locations:
  - App bundle root
  - App bundle `Models/`
  - Documents and `Documents/Models`
  - Application Support and `Application Support/Models`
- `LiteRTBridge` loads a runtime dylib with `dlopen`.
- If runtime/model init fails, app falls back to existing local inference chain.

## Runtime library lookup

At initialization, bridge checks in this order:

1. Env var `X_EYE_LITERT_BRIDGE_DYLIB`
2. `Frameworks/LiteRTLMBridge.framework/LiteRTLMBridge` in app bundle
3. `Frameworks/libLiteRTLMBridge.dylib` in app bundle
4. `libLiteRTLMBridge.dylib` in app bundle root
5. `Documents/libLiteRTLMBridge.dylib` in app data container
6. `Documents/LiteRTLMBridge.framework/LiteRTLMBridge` in app data container
7. `Application Support/libLiteRTLMBridge.dylib` in app data container
8. `Application Support/LiteRTLMBridge.framework/LiteRTLMBridge` in app data container

If no external library is found, the bridge also checks for the same C ABI
symbols linked into the app binary itself. This enables local development with
an in-app stub runtime.

Current implementation includes a development stub at
`Sources/App/LiteRTStubRuntime.mm`.

## Required C ABI symbols

Your LiteRT runtime library must export these symbols:

```c
int litertlm_create(const char* model_path, void** out_engine, char** out_error);
int litertlm_infer_rgba(
  void* engine,
  const uint8_t* rgba,
  int width,
  int height,
  int bytes_per_row,
  const char* prompt,
  char** out_text,
  char** out_error
);
void litertlm_destroy(void* engine);
void litertlm_free_string(char* value);
```

Conventions:

- Return `0` on success, non-zero on failure.
- On failure, set `*out_error` to a heap-allocated UTF-8 string.
- On success of inference, set `*out_text` to a heap-allocated UTF-8 string.
- `litertlm_free_string` must free strings returned via `out_error` and `out_text`.

## Next step to enable real LiteRT on iOS

1. Add runtime library (`.framework` or `.dylib`) exporting the ABI above.
2. Add the library to app bundle copy phase.
3. Place `gemma4.litertlm` in one of the searched locations.
4. Run app and verify backend label switches to `LiteRT-LM (iOS)`.

Notes:

- External runtime library always takes precedence over the in-app stub.
- Keep the stub only for development verification. Real quality/performance
  validation must use actual LiteRT runtime.

## Quick local verification (without external runtime)

1. Place a dummy model file named `gemma4.litertlm` into app Documents or app bundle Models.
2. Launch app on device.
3. Tap "調べる" and check inference label.

Expected behavior:

- Backend label becomes `LiteRT-LM (iOS)`.
- Response includes `LiteRT開発スタブ` text from stub runtime.
- If model file is missing, it gracefully falls back to AppleVision/Mock.

### Model upload helper

Use the helper script to copy a model file into app Documents on a connected device:

```bash
cd ios/XEye
./scripts/push_litert_model_to_device.sh /path/to/gemma4.litertlm
```

Optional env vars:

- `DEVICE_ID=<udid>`: choose a specific device
- `APP_BUNDLE_ID=<bundle-id>`: default is `com.example.xeyeios`
- `DESTINATION_PATH=<path-in-app-container>`: default is `Documents/gemma4.litertlm`

### Runtime upload helper

Use this when starting real LiteRT runtime integration without re-signing app bundle:

```bash
cd ios/XEye
./scripts/push_litert_runtime_to_device.sh /path/to/libLiteRTLMBridge.dylib
```

Optional env vars:

- `DEVICE_ID=<udid>`: choose a specific device
- `APP_BUNDLE_ID=<bundle-id>`: default is `com.example.xeyeios`
- `DESTINATION_PATH=<path-in-app-container>`: default is `Documents/libLiteRTLMBridge.dylib`
