#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[TavoLink] Flutter SDK not found in PATH" >&2
  exit 127
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "[TavoLink] python3 not found in PATH" >&2
  exit 127
fi

FLUTTER=(flutter --suppress-analytics --no-version-check)

# Native projects are committed. Only restore a platform when it is actually
# missing; never overwrite project signing, capabilities, icons, or build edits.
if [[ ! -f android/app/src/main/AndroidManifest.xml || ! -f ios/Runner/Info.plist ]]; then
  TMP_DIR="$(mktemp -d)"
  cleanup() { rm -rf "$TMP_DIR"; }
  trap cleanup EXIT

  "${FLUTTER[@]}" create \
    --no-pub \
    --platforms=android,ios \
    --org com.tavolink \
    --project-name tavolink \
    "$TMP_DIR/tavolink"

  if [[ ! -f android/app/src/main/AndroidManifest.xml ]]; then
    cp -R "$TMP_DIR/tavolink/android" ./android
  fi
  if [[ ! -f ios/Runner/Info.plist ]]; then
    cp -R "$TMP_DIR/tavolink/ios" ./ios
  fi
fi

python3 tool/patch_platforms.py
"${FLUTTER[@]}" pub get

echo "[TavoLink] Native Android/iOS projects verified and patched safely."
