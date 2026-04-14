#!/usr/bin/env bash
set -euo pipefail

PROJECT="XEyeApp.xcodeproj"
SCHEME="XEyeApp"
DEFAULT_DEVELOPMENT_TEAM="TEWA5M45RZ"
APP_BUNDLE_PATH="${HOME}/Library/Developer/Xcode/DerivedData/XEyeApp-aleqzkijkkiqliacsdwfeeygmtng/Build/Products/Debug-iphoneos/XEyeApp.app"
APP_BUNDLE_ID="com.example.xeyeios"
LAUNCH_JSON_PATH="/tmp/xeye_devicectl_launch.json"

print_launch_diagnostics() {
  if [[ ! -f "$LAUNCH_JSON_PATH" ]]; then
    return
  fi

  if grep -q '"string" : "Locked"' "$LAUNCH_JSON_PATH"; then
    echo "[blocked] Device is locked."
    echo "- Unlock iPhone and keep the screen on"
    echo "- Re-run this script"
    return
  fi

  if grep -q 'RequestDenied' "$LAUNCH_JSON_PATH"; then
    echo "[blocked] Launch request denied by SpringBoard."
    echo "- Confirm trust/profile is valid on device"
    echo "- Delete app from device and run script again"
    return
  fi

  local reason
  reason="$(grep -m 1 'NSLocalizedFailureReason' -A2 "$LAUNCH_JSON_PATH" | tail -n 1 | sed -E 's/^\s*"string"\s*:\s*"(.*)"/\1/' || true)"
  if [[ -n "$reason" ]]; then
    echo "[info] launch failure reason: $reason"
  fi
}

launch_with_retry() {
  local attempts=3
  local i=1

  while (( i <= attempts )); do
    echo "Launching app (attempt ${i}/${attempts})..."
    if xcrun devicectl \
      -j "$LAUNCH_JSON_PATH" \
      device process launch \
      --device "$SELECTED_DEVICE_ID" \
      --terminate-existing \
      "$APP_BUNDLE_ID"; then
      return 0
    fi

    print_launch_diagnostics
    ((i++))
  done

  return 1
}

show_destinations() {
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null || true
}

DEST_OUTPUT="$(show_destinations)"

if echo "$DEST_OUTPUT" | grep -q "pairing is in progress"; then
  echo "[blocked] Device pairing is still in progress."
  echo "- Unlock iPhone/iPad"
  echo "- Tap Trust on device"
  echo "- Keep cable connected until pairing completes"
  exit 2
fi

if [[ -n "${DEVICE_ID:-}" ]]; then
  SELECTED_DEVICE_ID="$DEVICE_ID"
else
  SELECTED_DEVICE_ID="$(echo "$DEST_OUTPUT" | awk '
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
  ')"
fi

if [[ -z "${SELECTED_DEVICE_ID}" ]]; then
  echo "[blocked] No eligible physical iOS device found."
  echo "Tip: run xcrun xctrace list devices and verify your device is online."
  exit 3
fi

EXTRA_ARGS=()
SELECTED_TEAM="${DEVELOPMENT_TEAM:-$DEFAULT_DEVELOPMENT_TEAM}"
if [[ -n "$SELECTED_TEAM" ]]; then
  EXTRA_ARGS+=("DEVELOPMENT_TEAM=$SELECTED_TEAM")
fi

if [[ -n "${PRODUCT_BUNDLE_IDENTIFIER:-}" ]]; then
  EXTRA_ARGS+=("PRODUCT_BUNDLE_IDENTIFIER=$PRODUCT_BUNDLE_IDENTIFIER")
fi

echo "Using device: $SELECTED_DEVICE_ID"

CMD=(
  xcodebuild
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "id=$SELECTED_DEVICE_ID"
  -allowProvisioningUpdates
  build
)

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  CMD+=("${EXTRA_ARGS[@]}")
fi

"${CMD[@]}"

if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
  echo "[blocked] Built app bundle not found: $APP_BUNDLE_PATH"
  exit 4
fi

xcrun devicectl device install app --device "$SELECTED_DEVICE_ID" "$APP_BUNDLE_PATH"

if ! launch_with_retry; then
  echo "[failed] App launch failed after retries."
  exit 5
fi

echo "[ok] Device build, install, and launch succeeded."
