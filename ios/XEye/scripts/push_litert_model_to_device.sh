#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.example.xeyeios}"
MODEL_PATH="${1:-}"
DESTINATION_PATH="${DESTINATION_PATH:-Documents/gemma4.litertlm}"

if [[ -z "$MODEL_PATH" ]]; then
  echo "Usage: $0 /path/to/gemma4.litertlm"
  exit 1
fi

if [[ ! -f "$MODEL_PATH" ]]; then
  echo "[blocked] Model file not found: $MODEL_PATH"
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
echo "Copying model: $MODEL_PATH -> $DESTINATION_PATH"

xcrun devicectl device copy to \
  --device "$SELECTED_DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$APP_BUNDLE_ID" \
  --source "$MODEL_PATH" \
  --destination "$DESTINATION_PATH"

echo "Verifying copied model file..."
xcrun devicectl device info files \
  --device "$SELECTED_DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$APP_BUNDLE_ID" \
  --subdirectory "Documents" \
  --filter "Name CONTAINS 'gemma4'"

echo "[ok] Model push completed."
