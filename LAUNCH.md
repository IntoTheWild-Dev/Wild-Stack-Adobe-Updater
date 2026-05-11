# Wild Stack — Adobe Marketplace Launch Guide

## Overview

This guide covers everything needed to take Wild Stack from local development to production on the Adobe Plugin Marketplace. There are **three separate systems** to prepare:

1. **Plugins** — packaged for Adobe Exchange submission
2. **Updater App** — signed, notarized, and distributed
3. **Backend** — license validation + purchase flow

---

## 1. Adobe Exchange Submission (Per Plugin)

Each plugin is listed separately on the Adobe Plugin Marketplace.

### Step 1: Create a Developer Account
1. Go to https://exchange.adobe.com
2. Sign up for a developer account (same Adobe ID)
3. Complete the partner/developer profile

### Step 2: Package Each Plugin

**After Effects — CEP → `.zxp`**

```bash
# 1. Create a signed .zxp using Adobe's ZXPSignCmd tool
# Download from: https://github.com/Adobe-CEP/CEP-Resources

ZXPSignCmd -sign \
  "Wild-Stack-AE-CompSwap" \
  "WildStackAECompSwap.zxp" \
  "your-certificate.p12" \
  "your-password"
```

**InDesign — UXP → `.ccx`**

```bash
# Using UXP Developer Tools CLI (bundled with UXP Dev Tool app)
# Or via the UXP Developer Tool GUI:
#  1. Open UXP Developer Tools
#  2. Click "Package" on the plugin
#  3. Export as .ccx

# CLI alternative:
UXPDeveloperTools package \
  --manifest "/path/to/Wild-Stack-ID-AssetSwap/manifest.json" \
  --output "WildStackIDAssetSwap.ccx"
```

**Photoshop — UXP → `.ccx`**

```bash
# Same as InDesign
UXPDeveloperTools package \
  --manifest "/path/to/Wild-Stack-PS-AssetSwap/manifest.json" \
  --output "WildStackPSAssetSwap.ccx"
```

### Step 3: Submit to Exchange
For each plugin:
1. Go to https://exchange.adobe.com → "Submit a product"
2. Fill in: name, description, category, pricing (free or paid)
3. Upload the `.zxp` / `.ccx` file
4. Upload icons (512x512), screenshots (at least 3)
5. Select compatible host app versions
6. Submit for review

**Review time:** 3-5 business days typical.

### Plugin Listing Specs

| Plugin | Exchange Name | Category | Pricing |
|--------|--------------|----------|---------|
| AE Comp Swap | Wild Stack AE Comp Swap | Workflow / Automation | Free trial, then paid |
| ID Asset Swap | Wild Stack Asset Swap | Workflow / Automation | Free trial, then paid |
| PS Asset Swap | Wild Stack Asset Swap | Workflow / Automation | Free trial, then paid |

---

## 2. GitHub Releases (Plugin Downloads)

The updater downloads plugins from GitHub Releases. Each plugin needs a release zip.

### Repo: `IntoTheWild-Dev/Wild-Stack-Adobe-Updater`

Create a release for each plugin:

```bash
# Inside each plugin directory, zip it with the correct folder name:

# AE (CEP) — folder name must be the plugin ID
cd "Wild-Stack-AE-CompSwap"
mkdir -p /tmp/release/com.wildagency.aestackcompswap
cp -R * /tmp/release/com.wildagency.aestackcompswap/
cd /tmp/release && zip -r WildStackAECompSwap.zip com.wildagency.aestackcompswap

# ID (UXP)
cd "Wild-Stack-ID-AssetSwap"
mkdir -p /tmp/release/com.wildagency.idstackautoupdate
cp -R * /tmp/release/com.wildagency.idstackautoupdate/
cd /tmp/release && zip -r WildStackIDAssetSwap.zip com.wildagency.idstackautoupdate

# PS (UXP)
cd "Wild-Stack-PS-AssetSwap"
mkdir -p /tmp/release/com.wildstack.psassetswap
cp -R * /tmp/release/com.wildstack.psassetswap/
cd /tmp/release && zip -r WildStackPSAssetSwap.zip com.wildstack.psassetswap
```

Then create GitHub Releases with tags `ae-v1.0.0`, `id-v1.0.0`, `ps-v1.0.0`.

### Get SHA-256 Hashes
```bash
shasum -a 256 WildStackAECompSwap.zip
shasum -a 256 WildStackIDAssetSwap.zip
shasum -a 256 WildStackPSAssetSwap.zip
```

Replace `REPLACE_WITH_SHA256` in `release-feed.json` with these values.

---

## 3. Release Feed (GitHub Pages)

The live feed is hosted at GitHub Pages in the `IntoTheWild-Dev/Wild-Stack-Adobe-Updater` repo.

### Update `release-feed.json` in the repo:
```json
{
  "feedVersion": 2,
  "updatedAt": "2026-05-11T00:00:00Z",
  "plugins": [
    {
      "id": "com.wildagency.aestackcompswap",
      "name": "Wild Stack AE Comp Swap",
      "description": "Swap compositions in After Effects with a single click.",
      "host": "aftereffects",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "22.0",
      "downloadURL": "https://github.com/IntoTheWild-Dev/Wild-Stack-Adobe-Updater/releases/download/ae-v1.0.0/WildStackAECompSwap.zip",
      "sha256": "ACTUAL_SHA256_HERE",
      "releaseNotes": "Initial release."
    },
    {
      "id": "com.wildagency.idstackautoupdate",
      "name": "Wild Stack Asset Swap",
      "description": "Auto-Update layers in InDesign faster.",
      "host": "indesign",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "18.0",
      "downloadURL": "https://github.com/IntoTheWild-Dev/Wild-Stack-Adobe-Updater/releases/download/id-v1.0.0/WildStackIDAssetSwap.zip",
      "sha256": "ACTUAL_SHA256_HERE",
      "releaseNotes": "Initial release."
    },
    {
      "id": "com.wildstack.psassetswap",
      "name": "Wild Stack Asset Swap",
      "description": "Auto-Update layers in Photoshop faster.",
      "host": "photoshop",
      "currentVersion": "1.0.0",
      "minimumHostVersion": "22.0.0",
      "downloadURL": "https://github.com/IntoTheWild-Dev/Wild-Stack-Adobe-Updater/releases/download/ps-v1.0.0/WildStackPSAssetSwap.zip",
      "sha256": "ACTUAL_SHA256_HERE",
      "releaseNotes": "Initial release."
    }
  ]
}
```

The feed URL (as used by the updater):
```
https://intothewild-dev.github.io/Wild-Stack-Adobe-Updater/release-feed.json
```

---

## 4. License Backend Setup

The updater validates license keys against a server. Without a server, it accepts any key >= 8 characters locally.  

### API Contract

**Endpoint:** `POST {your-server}/api/v1/validate`

**Request:**
```json
{
  "licenseKey": "XXXX-XXXX-XXXX",
  "pluginId":   "com.wildagency.aestackcompswap",
  "machineId":  "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (valid):**
```json
{ "valid": true }
```

**Response (invalid):**
```json
{ "valid": false }
```

### Configure the Updater
```bash
# Set validation server URL
defaults write com.wildagency.WildStackUpdater WildStack.license.validationURL \
  "https://your-api.com/api/v1/validate"

# Set purchase page URL
defaults write com.wildagency.WildStackUpdater WildStack.license.purchaseURL \
  "https://intothewild.dev/purchase"
```

### License Key Format
Define your key format with the backend developer. Example:
- `WS-AE-XXXX-XXXX-XXXX` (Wild Stack, After Effects)
- `WS-ID-XXXX-XXXX-XXXX` (Wild Stack, InDesign)
- `WS-PS-XXXX-XXXX-XXXX` (Wild Stack, Photoshop)

---

## 5. Updater App — Signing & Distribution

### Apple Developer Account Required
1. Enroll at https://developer.apple.com ($99/year)
2. Create a "Developer ID Application" certificate
3. Create app-specific password for notarization

### Sign & Notarize
```bash
# Build release
swift build -c release

# Sign
codesign --deep --force --sign "Developer ID Application: Your Name (TEAMID)" \
  --options runtime \
  WildStackUpdater.app

# Create dmg
hdiutil create -volname "WildStackUpdater" -srcfolder WildStackUpdater.app \
  -ov -format UDZO WildStackUpdater.dmg

# Sign dmg
codesign --sign "Developer ID Application: Your Name (TEAMID)" WildStackUpdater.dmg

# Notarize
xcrun notarytool submit WildStackUpdater.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "@keychain:notary-password" \
  --wait

# Staple ticket
xcrun stapler staple WildStackUpdater.dmg
```

### Distribution
- Host the `.dmg` on your website or GitHub Releases
- Users download → open → drag to Applications
- The app self-updates via Sparkle (appcast.xml)

### Sparkle Appcast
Host an `appcast.xml` on your server. Use the Sparkle `generate_appcast` tool:
```bash
generate_appcast /path/to/releases/
```

Update the `SUFeedURL` in `Info.plist`:
```xml
<key>SUFeedURL</key>
<string>https://intothewild.dev/appcast.xml</string>
```

---

## 6. UXP Strategy Decision

**Current state:** UXP plugins installed by the updater need UXP Developer Tool to load.

**Option A: Exchange-only distribution (Recommended)**
- Users install `.ccx` from Adobe Exchange → Creative Cloud handles loading
- The updater manages: licensing, version checks, update notifications
- Less complex, follows Adobe's intended workflow

**Option B: Updater handles everything**
- Updater installs UXP plugins to Adobe's extensions folders
- Requires users to have UXP Developer Mode enabled
- More control, but more friction

**Recommendation:** Go with Option A. List plugins on Exchange, bundles `.ccx` files there. The updater becomes a license manager + update checker rather than an installer for UXP plugins.

---

## 7. Step-by-Step Launch Checklist

### Phase 1 — Plugin Packaging
- [ ] Package AE plugin as `.zxp`
- [ ] Package ID plugin as `.ccx`  
- [ ] Package PS plugin as `.ccx`
- [ ] Create icons (512x512) for each plugin
- [ ] Take 3+ screenshots per plugin
- [ ] Write descriptions for Exchange listings
- [ ] Submit all 3 to Adobe Exchange

### Phase 2 — GitHub & Feed
- [ ] Create GitHub Releases with plugin zips
- [ ] Generate SHA-256 hashes for each zip
- [ ] Update `release-feed.json` with real hashes and PS entry
- [ ] Deploy feed to GitHub Pages
- [ ] Verify updater fetches feed correctly

### Phase 3 — Updater App
- [ ] Update `PluginStore.swift` — change `defaultFeedURL` to production
- [ ] Update `Info.plist` — change `SUFeedURL` to production
- [ ] Update purchase URL (via UserDefaults or code)
- [ ] Sign with Developer ID
- [ ] Notarize
- [ ] Package as `.dmg`
- [ ] Upload to website / GitHub Releases

### Phase 4 — Backend
- [ ] Build license validation API endpoint
- [ ] Build purchase flow (link from license sheet)
- [ ] Generate license keys for each plugin
- [ ] Set `WildStack.license.validationURL` in updater
- [ ] Set `WildStack.license.purchaseURL` in updater
- [ ] Test end-to-end: install → trial → activate → purchase

### Phase 5 — Launch
- [ ] Final QA on clean machine
- [ ] Test trial flow for each plugin
- [ ] Test license activation for each plugin
- [ ] Test Sparkle auto-update
- [ ] Publish Exchange listings
- [ ] Publish updater download page
- [ ] Announce

---

## 8. Quick Reference — What to Replace

| File | Line / Key | Replace With |
|------|-----------|--------------|
| `PluginStore.swift` | `defaultFeedURL` | Your production feed URL |
| `Info.plist` | `SUFeedURL` | Your production appcast URL |
| `Info.plist` | `SUPublicEDKey` | Your Sparkle EdDSA public key |
| `Info.plist` | `CFBundleIdentifier` | Your production bundle ID |
| `release-feed.json` | All `sha256` values | Real zip hashes |
| `release-feed.json` | All `downloadURL` values | Real GitHub Release URLs |
| UserDefaults | `WildStack.license.purchaseURL` | Your purchase page |
| UserDefaults | `WildStack.license.validationURL` | Your license API |
| `Debug.xcconfig` | `DEVELOPMENT_TEAM` | Your Apple Team ID |
| `Debug.xcconfig` | `CODE_SIGN_IDENTITY` | Your signing identity |

---

## Support Files in This Repo

| File | Purpose |
|------|---------|
| `run-local.sh` | Build & launch updater with live feed |
| `test-local.sh` | Build & launch with local plugin zips |
| `STATUS.md` | Current dev status & known issues |
| `LAUNCH.md` | This file — launch guide |
