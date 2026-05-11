#!/bin/bash
# test-local.sh
# Zips your local plugins, creates a local release feed pointing to them,
# builds the updater, and launches it in local-test mode.
# Usage:  bash test-local.sh

set -euo pipefail
cd "$(dirname "$0")"

BUILD="$(pwd)/.build/arm64-apple-macosx/debug"
APP="$(pwd)/.build/WildStackUpdater.app"
PLIST="$(pwd)/Sources/WildStackUpdater/Resources/Info.plist"
PLUGINS_DIR="/Users/juliatstadlertheunissen/Documents/Creative_Devs /Wild Stack Adobe Plugins"
TEST_DIR="$(pwd)/.test-data"

# ── 1. Create test data directory ───────────────────────────────────────────
echo "[1/6] Preparing test data..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/zips"

# ── 2. Zip each plugin ──────────────────────────────────────────────────────
echo "[2/6] Zipping plugins..."

# AE Comp Swap (CEP)
echo "  → AE Comp Swap..."
cp -R "$PLUGINS_DIR/Wild-Stack-AE-CompSwap" "$TEST_DIR/tmp-ae"
rm -rf "$TEST_DIR/tmp-ae/.git" "$TEST_DIR/tmp-ae/.claude" 2>/dev/null || true
mv "$TEST_DIR/tmp-ae" "$TEST_DIR/com.wildagency.aestackcompswap"
cd "$TEST_DIR" && zip -rq "zips/ae.zip" "com.wildagency.aestackcompswap"
rm -rf "$TEST_DIR/com.wildagency.aestackcompswap"

# ID Asset Swap (UXP)
echo "  → ID Asset Swap..."
cp -R "$PLUGINS_DIR/Wild-Stack-ID-AssetSwap" "$TEST_DIR/tmp-id"
rm -rf "$TEST_DIR/tmp-id/.git" "$TEST_DIR/tmp-id/.claude" 2>/dev/null || true
mv "$TEST_DIR/tmp-id" "$TEST_DIR/com.wildagency.idstackautoupdate"
cd "$TEST_DIR" && zip -rq "zips/id.zip" "com.wildagency.idstackautoupdate"
rm -rf "$TEST_DIR/com.wildagency.idstackautoupdate"

# PS Asset Swap (UXP)
echo "  → PS Asset Swap..."
cp -R "$PLUGINS_DIR/Wild-Stack-PS-AssetSwap" "$TEST_DIR/tmp-ps"
rm -rf "$TEST_DIR/tmp-ps/.git" "$TEST_DIR/tmp-ps/.claude" 2>/dev/null || true
mv "$TEST_DIR/tmp-ps" "$TEST_DIR/com.wildstack.psassetswap"
cd "$TEST_DIR" && zip -rq "zips/ps.zip" "com.wildstack.psassetswap"
rm -rf "$TEST_DIR/com.wildstack.psassetswap"

cd "$(dirname "$0")"

# ── 3. Generate local feed ──────────────────────────────────────────────────
echo "[3/6] Generating local release feed..."
FEED="$TEST_DIR/test-feed.json"
ZIPS_DIR="file://$TEST_DIR/zips"

cat > "$FEED" <<FEEDEOF
{
  "feedVersion": 1,
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "plugins": [
    {
      "id": "com.wildagency.aestackcompswap",
      "name": "Wild Stack AE Comp Swap",
      "description": "Swap compositions in After Effects with a single click.",
      "host": "aftereffects",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "22.0",
      "downloadURL": "$ZIPS_DIR/ae.zip",
      "sha256": "REPLACE_WITH_SHA256",
      "releaseNotes": "Local test build."
    },
    {
      "id": "com.wildagency.idstackautoupdate",
      "name": "Wild Stack Asset Swap",
      "description": "Auto-Update layers in InDesign faster.",
      "host": "indesign",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "18.0",
      "downloadURL": "$ZIPS_DIR/id.zip",
      "sha256": "REPLACE_WITH_SHA256",
      "releaseNotes": "Local test build."
    },
    {
      "id": "com.wildstack.psassetswap",
      "name": "Wild Stack Asset Swap",
      "description": "Auto-Update layers in Photoshop faster.",
      "host": "photoshop",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "22.0.0",
      "downloadURL": "$ZIPS_DIR/ps.zip",
      "sha256": "REPLACE_WITH_SHA256",
      "releaseNotes": "Local test build."
    }
  ]
}
FEEDEOF

echo "   Feed written to: $FEED"

# ── 4. Build ────────────────────────────────────────────────────────────────
echo "[4/6] Building..."
swift build

# ── 5. Kill existing + assemble .app ────────────────────────────────────────
echo "[5/6] Assembling .app bundle..."
pkill -x WildStackUpdater 2>/dev/null || true
sleep 0.3

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BUILD/WildStackUpdater" "$APP/Contents/MacOS/"
cp "$PLIST" "$APP/Contents/Info.plist"
cp -R "$BUILD/Sparkle.framework" "$APP/Contents/MacOS/"

# Clean extended attributes to avoid signing errors
xattr -cr "$APP" 2>/dev/null || true

codesign --force --deep --sign - "$APP"

# ── 6. Launch with local feed ───────────────────────────────────────────────
echo "[6/6] Launching with local test feed..."
open "$APP" --args --local-feed "$FEED"

echo ""
echo "Done — Updater is running with local test feed."
echo "All 3 plugins should appear as 'Try Free'."
echo ""
echo "To skip trial limits:"
echo "  defaults write com.wildagency.WildStackUpdater WildStack.license.agencyKey test-key"
echo ""
echo "To reset everything:"
echo "  defaults delete com.wildagency.WildStackUpdater"
