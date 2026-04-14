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
