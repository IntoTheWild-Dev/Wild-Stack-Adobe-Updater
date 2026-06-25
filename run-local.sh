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
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

echo "[4/4] Building demo feed with local ZIPs..."
DEMO_FEED="$(pwd)/.build/demo-feed.json"
DIST="$(pwd)/dist"
AE_SHA=$(shasum -a 256 "$DIST/WildStackAECompSwap.zip"  | awk '{print $1}')
ID_SHA=$(shasum -a 256 "$DIST/WildStackIDAssetSwap.zip" | awk '{print $1}')
PS_SHA=$(shasum -a 256 "$DIST/WildStackPSAssetSwap.zip" | awk '{print $1}')

cat > "$DEMO_FEED" <<FEEDEOF
{
  "feedVersion": 1,
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "plugins": [
    {
      "id": "com.wildagency.aestackcompswap",
      "name": "Wild Stack AE Comp Swap",
      "description": "Swap compositions and images in After Effects with a single click.",
      "host": "aftereffects",
      "currentVersion": "2.4.0",
      "minimumHostVersion": "22.0",
      "downloadURL": "file://$DIST/WildStackAECompSwap.zip",
      "sha256": "$AE_SHA",
      "releaseNotes": "Multi-layer select, 1-file-to-all-layers, uniform scale hero swap."
    },
    {
      "id": "com.wildagency.idstackautoupdate",
      "name": "Wild Stack ID Asset Swap",
      "description": "Swap images and text frames in InDesign from a CSV or JSON data source.",
      "host": "indesign",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "18.0",
      "downloadURL": "file://$DIST/WildStackIDAssetSwap.zip",
      "sha256": "$ID_SHA",
      "releaseNotes": "Initial release."
    },
    {
      "id": "com.wildstack.psassetswap",
      "name": "Wild Stack PS Asset Swap",
      "description": "Replace smart object contents and text in Photoshop in bulk.",
      "host": "photoshop",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "24.0",
      "downloadURL": "file://$DIST/WildStackPSAssetSwap.zip",
      "sha256": "$PS_SHA",
      "releaseNotes": "Initial release."
    }
  ]
}
FEEDEOF

echo "[5/4] Launching..."
open "$APP" --args --local-feed "$DEMO_FEED"

echo "Done — Wild Stack Updater is running."
