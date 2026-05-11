#!/bin/bash
# run-local.sh
# Builds Wild Stack Updater, assembles a proper .app bundle,
# signs it ad-hoc (no Apple Developer account required), and opens it.
# Usage:  bash run-local.sh

set -euo pipefail
cd "$(dirname "$0")"

BUILD="$(pwd)/.build/arm64-apple-macosx/debug"
APP="$(pwd)/.build/WildStackUpdater.app"
PLIST="$(pwd)/Sources/WildStackUpdater/Resources/Info.plist"

# ── 1. Build ───────────────────────────────────────────────────────────────
echo "[1/4] Building..."
swift build

# ── 2. Kill any existing instance ─────────────────────────────────────────
pkill -x WildStackUpdater 2>/dev/null || true
sleep 0.3

# ── 3. Assemble .app bundle ────────────────────────────────────────────────
echo "[2/4] Assembling .app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Main binary
cp "$BUILD/WildStackUpdater" "$APP/Contents/MacOS/"

# Info.plist — provides CFBundleIdentifier, SUFeedURL, SUPublicEDKey
cp "$PLIST" "$APP/Contents/Info.plist"

# Sparkle.framework must sit beside the binary so @loader_path resolves
cp -R "$BUILD/Sparkle.framework" "$APP/Contents/MacOS/"

# ── 4. Sign ad-hoc + open ─────────────────────────────────────────────────
echo "[3/4] Signing ad-hoc..."
codesign --force --deep --sign - "$APP"

echo "[4/4] Launching..."
open "$APP"

echo "Done — Wild Stack Updater is running."
