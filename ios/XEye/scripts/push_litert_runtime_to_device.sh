#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.example.xeyeios}"
RUNTIME_PATH="${1:-}"
DESTINATION_PATH="${DESTINATION_PATH:-Documents/libLiteRTLMBridge.dylib}"

if [[ -z "$RUNTIME_PATH" ]]; then
  echo "Usage: $0 /path/to/libLiteRTLMBridge.dylib"
  exit 1
fi

if [[ ! -f "$RUNTIME_PATH" ]]; then
  echo "[blocked] Runtime library not found: $RUNTIME_PATH"
  exit 2
fi

resolve_device_id() {
  if [[ -n "${DEVICE_ID:-}" ]]; then
    echo "$DEVICE_ID"
    return 0
  fi

  local destinations
  destinations="$(xcodebuild -project XEyeApp.xcodeproj -scheme XEyeApp -showdestinations 2>/dev/null || true)"

  if echo "$destinations" | grep -q "pairing is in progress"; then
    echo "[blocked] Device pairing is still in progress." >&2
    return 1
  fi

  echo "$destinations" | awk '
    /\{ platform:iOS,/ && /id:/ && /name:/ {
      if ($0 !~ /placeholder/) {
        line=$0
        sub(/^.*id:/, "", line)
        sub(/,.*/, "", line)
        gsub(/[[:space:]]/, "", line)
        print line
        exit
      }
    }
  '
}

SELECTED_DEVICE_ID="$(resolve_device_id)"
if [[ -z "$SELECTED_DEVICE_ID" ]]; then
  echo "[blocked] No eligible iOS device found."
  exit 3
fi

echo "Using device: $SELECTED_DEVICE_ID"
echo "Copying runtime: $RUNTIME_PATH -> $DESTINATION_PATH"

xcrun devicectl device copy to \
  --device "$SELECTED_DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$APP_BUNDLE_ID" \
  --source "$RUNTIME_PATH" \
  --destination "$DESTINATION_PATH"

echo "Verifying copied runtime file..."
xcrun devicectl device info files \
  --device "$SELECTED_DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$APP_BUNDLE_ID" \
  --subdirectory "Documents" \
  --filter "Name CONTAINS 'LiteRTLMBridge'"

echo "[ok] Runtime push completed."
