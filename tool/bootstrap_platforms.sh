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

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Generate native scaffolds in an isolated temporary project so Flutter never
# overwrites TavoLink's lib/, test/, assets, or pubspec.yaml.
flutter create \
  --platforms=android,ios \
  --org com.tavolink \
  --project-name tavolink \
  "$TMP_DIR/tavolink"

rm -rf android ios
cp -R "$TMP_DIR/tavolink/android" ./android
cp -R "$TMP_DIR/tavolink/ios" ./ios

python3 tool/patch_platforms.py
flutter pub get

echo "[TavoLink] Native Android/iOS scaffolds regenerated and patched safely."
