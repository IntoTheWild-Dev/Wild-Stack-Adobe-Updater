# For the Developer — Backend & Packaging Tasks

## Overview

You need to build:

1. **License key generation** — a system to create and manage activation keys
2. **License validation API** — one endpoint the updater calls
3. **Plugin packaging** — `.zxp` and `.ccx` files for Adobe Exchange

---

## 1. License Validation API

### One endpoint only

```
POST /api/v1/validate
Content-Type: application/json
```

### Request (what the updater sends)
```json
{
  "licenseKey": "WS-AE-A1B2-C3D4-E5F6",
  "pluginId":   "com.wildagency.aestackcompswap",
  "machineId":  "550e8400-e29b-41d4-a716-446655440000"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `licenseKey` | string | The key the user entered |
| `pluginId` | string | Which plugin they're activating |
| `machineId` | string | UUID unique to that user's Mac |

### Response (valid key)
```json
{ "valid": true }
```

### Response (invalid / already used / expired)
```json
{ "valid": false }
```

### Logic
```
1. Check if licenseKey exists in database
2. Check it matches pluginId
3. Check it's not already activated on a different machine
   - If first activation: bind key → machineId
   - If same machine: allow (re-activation after reinstall)
   - If different machine: reject (key already in use)
4. Check it's not expired (if you add dates later)
5. Return { valid: true/false }
```

### Three Plugin IDs
```
com.wildagency.aestackcompswap   → After Effects
com.wildagency.idstackautoupdate  → InDesign
com.wildstack.psassetswap         → Photoshop
```

---

## 2. License Key Generation

### Suggested Format
```
WS-{APP}-{4x4 HEX}
WS-AE-A1B2-C3D4-E5F6   (After Effects)
WS-ID-7F8A-9B0C-1D2E   (InDesign)
WS-PS-3F4A-5B6C-7D8E   (Photoshop)
```

### Database Schema
```sql
CREATE TABLE license_keys (
    id            TEXT PRIMARY KEY,     -- the key itself, e.g. "WS-AE-A1B2-C3D4-E5F6"
    plugin_id     TEXT NOT NULL,        -- "com.wildagency.aestackcompswap"
    created_at    TIMESTAMP DEFAULT NOW(),
    activated_at  TIMESTAMP,
    machine_id    TEXT,                 -- bound to this machine after first activation
    status        TEXT DEFAULT 'unused' -- 'unused' | 'active' | 'revoked'
);
```

### Generate a Batch
Simple script — generate 100 keys per plugin:

```python
import uuid, secrets

def generate_keys(plugin_prefix, count=100):
    for _ in range(count):
        segments = [secrets.token_hex(2).upper() for _ in range(3)]
        key = f"WS-{plugin_prefix}-{'-'.join(segments)}"
        # Insert into database
        print(key)
```

---

## 3. Plugin Packaging for Adobe Exchange

### After Effects (.zxp — CEP)

Requires Adobe's ZXPSignCmd tool:
- Download: https://github.com/Adobe-CEP/CEP-Resources
- You need a **code signing certificate** (can be self-signed for Exchange submission)

```bash
# Generate self-signed cert (for Exchange — they accept these)
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out cert.pem
openssl pkcs12 -export -in cert.pem -inkey key.pem -out cert.p12 -passout pass:wildstack

# Package the AE plugin
cd "Wild-Stack-AE-CompSwap"
ZXPSignCmd -sign . WildStackAECompSwap.zxp cert.p12 wildstack

# Verify
ZXPSignCmd -verify WildStackAECompSwap.zxp
```

File to give to the boss: `WildStackAECompSwap.zxp`

### InDesign + Photoshop (.ccx — UXP)

Use Adobe UXP Developer Tools:
- Already installed at `/Applications/Adobe UXP Developer Tools`

**Via GUI:**
1. Open UXP Developer Tools
2. Click the plugin → "Package"
3. Export as `.ccx`

**Via CLI:**
```bash
# InDesign
cd "Wild-Stack-ID-AssetSwap"
# Use UXP Developer Tools CLI to package
/path/to/UXPDeveloperTools package \
  --manifest manifest.json \
  --output WildStackIDAssetSwap.ccx

# Photoshop  
cd "Wild-Stack-PS-AssetSwap"
/path/to/UXPDeveloperTools package \
  --manifest manifest.json \
  --output WildStackPSAssetSwap.ccx
```

Files to give to the boss: `WildStackIDAssetSwap.ccx`, `WildStackPSAssetSwap.ccx`

---

## 4. GitHub Releases

Each plugin needs a release zip on GitHub in the repo: `IntoTheWild-Dev/Wild-Stack-Adobe-Updater`

```bash
# For each plugin, create a zip where the root folder = plugin ID:

# AE
mkdir -p /tmp/ae/com.wildagency.aestackcompswap
cp -R "Wild-Stack-AE-CompSwap/"* /tmp/ae/com.wildagency.aestackcompswap/
cd /tmp/ae && zip -r WildStackAECompSwap.zip com.wildagency.aestackcompswap

# ID
mkdir -p /tmp/id/com.wildagency.idstackautoupdate
cp -R "Wild-Stack-ID-AssetSwap/"* /tmp/id/com.wildagency.idstackautoupdate/
cd /tmp/id && zip -r WildStackIDAssetSwap.zip com.wildagency.idstackautoupdate

# PS  
mkdir -p /tmp/ps/com.wildstack.psassetswap
cp -R "Wild-Stack-PS-AssetSwap/"* /tmp/ps/com.wildstack.psassetswap/
cd /tmp/ps && zip -r WildStackPSAssetSwap.zip com.wildstack.psassetswap
```

Create GitHub Releases with tags: `ae-v1.0.0`, `id-v1.0.0`, `ps-v1.0.0`

Generate SHA-256 hashes:
```bash
shasum -a 256 WildStackAECompSwap.zip
shasum -a 256 WildStackIDAssetSwap.zip
shasum -a 256 WildStackPSAssetSwap.zip
```

Update `release-feed.json` in the repo with these hashes.

---

## 5. Purchase Page (Separate Task)

The updater's "Buy License" button opens a URL. You need:
- A purchase page at e.g. `https://intothewild.dev/purchase`
- After purchase → generate a key → email it to the customer → they paste it into the updater

OR use an existing platform (Gumroad, LemonSqueezy, Paddle) that handles purchases + key delivery.

---

## 6. Configuring the Updater

When the backend is live, set these on the updater:

```bash
defaults write com.wildagency.WildStackUpdater WildStack.license.validationURL \
  "https://your-server.com/api/v1/validate"

defaults write com.wildagency.WildStackUpdater WildStack.license.purchaseURL \
  "https://intothewild.dev/purchase"
```

---

## Summary — What You Need to Deliver

| Deliverable | Format | For Whom |
|------------|--------|----------|
| AE Comp Swap package | `.zxp` | Boss (Exchange submission) |
| ID Asset Swap package | `.ccx` | Boss (Exchange submission) |
| PS Asset Swap package | `.ccx` | Boss (Exchange submission) |
| License database + key generation | Code/DB | Production |
| Validation API (`POST /api/v1/validate`) | Live endpoint | Production |
| Purchase page | Live URL | Production |
| GitHub Release zips | `.zip` | Production |
| SHA-256 hashes | Text | Update `release-feed.json` |
