# WildStackUpdater — Status & Roadmap

**Last updated:** 11 May 2026

---

## Current State

### UI & Core Flow: Tested & Working
- Native macOS SwiftUI app (macOS 13+)
- Dark-themed UI matching Wild Stack brand (`intothewild.dev`)
- Auto-detects Adobe host apps (AE, ID, PS) — handles both direct `.app` and Creative Cloud wrapper folders
- All 3 plugins appear with "Try Free" buttons in local test mode
- License sheet with "Buy License" link works

### Three Plugins: All Connected

| # | Plugin | Host | ID | Type | Install Dir | Test Status |
|---|--------|------|----|------|-------------|-------------|
| 1 | Wild Stack AE Comp Swap | After Effects | `com.wildagency.aestackcompswap` | CEP | `Adobe/CEP/extensions/` | Verified |
| 2 | Wild Stack Asset Swap | InDesign | `com.wildagency.idstackautoupdate` | UXP | `Adobe/UXP/PluginsStorage/IDSN/` | Needs UXP Dev Tool |
| 3 | Wild Stack Asset Swap | Photoshop | `com.wildstack.psassetswap` | UXP | `Adobe/UXP/extensions/` | Needs UXP Dev Tool |

### Known Limitation: UXP Plugin Loading
UXP plugins (ID, PS) installed by the updater do **not** auto-load in their host apps. During development, UXP plugins must be loaded via **Adobe UXP Developer Tools**. This affects local testing only — marketplace `.ccx` installs handle this automatically.

**Local workaround:** Open UXP Developer Tools → "Add Plugin" → select the plugin folder → "Load".

**Production fix:** When distributed via Adobe Exchange (`.ccx` format), Creative Cloud handles loading. The updater's role shifts to version management + licensing.

### Licensing: Implemented

| Feature | Status |
|---------|--------|
| 1 free trial per plugin | Done (UserDefaults) |
| Trial state badge in UI | Done |
| License key input sheet | Done |
| License key storage | Done |
| Server-side validation | Ready, needs backend URL |
| Purchase link ("Buy License") | Placeholder URL set |
| Agency override key | Done |

---

## How Licensing Works

```
User opens app → sees plugins with "1 free trial available" badge
     ↓
Clicks "Try Free" → plugin installs → trial marked as used
     ↓
After trial: "Trial used — Activate license" + lock icon
     ↓
Clicks "Activate" → license key sheet opens
     ↓
Enters key → validated (locally for now, server-ready)
     ↓
Plugin unlocked → normal Install/Update/Installed flow
```

**"Buy License" button** opens configurable URL — default: `https://intothewild.dev/purchase`

---

## Places That Need Configuring for Launch

These values must be updated before production:

| What | Where | Current Value |
|------|-------|---------------|
| Release feed URL | `PluginStore.swift:20` | `intothewild-dev.github.io/.../release-feed.json` |
| Sparkle appcast | `Info.plist` (SUFeedURL) | `intothewild-dev.github.io/.../appcast.xml` |
| Purchase page URL | UserDefaults `WildStack.license.purchaseURL` | `https://intothewild.dev/purchase` |
| License validation API | UserDefaults `WildStack.license.validationURL` | *(not set — local validation)* |
| Bundle ID | `Info.plist` | `com.wildagency.WildStackUpdater` |

### Changing default URLs (without UserDefaults)

```bash
# Set in code — PluginStore.swift line 20
nonisolated static let defaultFeedURL = URL(string: "https://YOUR_DOMAIN/feed.json")!

# Set in Info.plist
<key>SUFeedURL</key>
<string>https://YOUR_DOMAIN/appcast.xml</string>
```

---

## Testing

### Local test (all 3 plugins from your machine)
```bash
cd WildStackUpdater
bash test-local.sh
```

### Unlimited trials (agency key)
```bash
defaults write com.wildagency.WildStackUpdater WildStack.license.agencyKey "test-key"
```

### Reset everything
```bash
defaults delete com.wildagency.WildStackUpdater
```

### Build & run (uses live feed, not local)
```bash
./run-local.sh
```

---

## Next Steps

### Immediate
- [ ] **UXP loading strategy** — decide whether to use UXP Dev Tool for distribution or switch to `.ccx` packaging only
- [ ] **Live release feed** — add PS plugin entry to GitHub Pages feed
- [ ] **GitHub Releases** — create release zips for all 3 plugins on GitHub
- [ ] **SHA-256 hashes** — replace `REPLACE_WITH_SHA256` with real hashes
- [ ] **Test UXP plugins in ID/PS** — verify loading behaviour in production scenario

### Before Launch
- [ ] **Package plugins for Exchange** — `.zxp` (AE), `.ccx` (ID, PS)
- [ ] **Submit to Adobe Exchange** — each plugin as separate listing
- [ ] **Sign & notarize** the `.app` bundle for distribution
- [ ] **Backend activation API** — build the license validation server
- [ ] **Set production URLs** — purchase page, validation API, feed, appcast

### Future
- [ ] License deactivation / transfer
- [ ] License expiration dates
- [ ] Usage analytics (opt-in)
- [ ] Windows support

---

## File Map

```
WildStackUpdater/
├── Sources/WildStackUpdater/
│   ├── WildStackUpdaterApp.swift      # @main entry + --local-feed CLI
│   ├── ContentView.swift              # Main window + license sheet wiring
│   ├── Models/
│   │   ├── Plugin.swift               # PluginHost, Plugin, PluginEntry, InstallState
│   │   ├── LicenseState.swift         # trialAvailable / trialUsed / licensed
│   │   ├── ReleaseFeed.swift          # JSON feed model
│   │   └── SemanticVersion.swift      # Version parsing
│   ├── Services/
│   │   ├── PluginStore.swift          # Main state store (MVVM)
│   │   ├── LicenseManager.swift       # Trial + license + agency key
│   │   ├── InstallEngine.swift        # Download / verify / extract / install
│   │   ├── FeedParser.swift           # Fetch + cache release feed
│   │   ├── HostDetector.swift         # Scan for Adobe apps (CC wrapper support)
│   │   └── SparkleUpdater.swift       # Self-update wrapper
│   ├── Views/
│   │   ├── PluginCardView.swift       # Plugin card with trial/license states
│   │   ├── LicenseSheetView.swift     # License key activation modal
│   │   ├── EmptyStateView.swift       # Loading / error / empty
│   │   └── DesignSystem.swift         # Brand colours + typography
│   └── Resources/
│       ├── Info.plist
│       ├── release-feed.json          # Bundled feed (reference only)
│       └── release-feed.example.json  # Template
├── Package.swift
├── run-local.sh                       # Build + launch with live feed
├── test-local.sh                      # Build + launch with local zips
├── STATUS.md                          # This file
├── LAUNCH.md                          # Marketplace launch guide
└── Configurations/Debug.xcconfig
```
