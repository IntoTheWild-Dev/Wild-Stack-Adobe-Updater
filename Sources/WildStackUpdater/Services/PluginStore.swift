import Foundation

@MainActor
final class PluginStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var entries:       [PluginEntry]                         = []
    @Published private(set) var detectedHosts: [PluginHost: HostDetector.DetectedHost] = [:]
    @Published private(set) var isLoading     = false
    @Published private(set) var feedError:     String?
    @Published private(set) var lastChecked:   Date?

    /// When non-nil, the license-activation sheet should be presented for this plugin.
    @Published var licenseActionPlugin: Plugin?

    // MARK: - Dependencies

    private let feedParser: FeedParser
    private let engine = InstallEngine()
    let licenseManager = LicenseManager()

    nonisolated static let defaultFeedURL = URL(
        string: "https://intothewild-dev.github.io/Wild-Stack-Adobe-Updater/release-feed.json"
    )!

    var purchaseURL: URL { licenseManager.purchaseURL }

    init(feedURL: URL = defaultFeedURL) {
        self.feedParser = FeedParser(feedURL: feedURL)
        // Load any cached feed instantly so the UI isn't blank on launch,
        // then kick off a live refresh in the background.
        if let cached = feedParser.fetchCached() {
            Task { self.entries = await self.resolveInstallStates(for: cached) }
        }
        Task { await refresh() }
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        feedError = nil

        detectedHosts = HostDetector.detectAll()

        do {
            let plugins = try await feedParser.fetch()
            entries     = await resolveInstallStates(for: plugins)
            lastChecked = Date()
            feedError   = nil
        } catch {
            // Preserve whatever is already showing; just surface the error.
            feedError = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Install / Update

    func install(entry: PluginEntry) {
        guard entry.installState.isIdle else { return }

        // Check license state before allowing install.
        let licenseState = licenseManager.state(for: entry.plugin.id)
        guard licenseState.canInstall else {
            licenseActionPlugin = entry.plugin
            return
        }

        update(id: entry.id, state: .installing(progress: 0))

        Task {
            do {
                try await engine.install(plugin: entry.plugin) { [weak self] progress in
                    self?.update(id: entry.plugin.id, state: .installing(progress: progress))
                }
                // Mark trial as used (idempotent — only matters for first install).
                licenseManager.markTrialUsed(for: entry.plugin.id)
                // Re-read the manifest version that was just written to disk.
                let version = await engine.installedVersion(for: entry.plugin)
                    ?? entry.plugin.currentVersion
                let newLicenseState = licenseManager.state(for: entry.plugin.id)
                update(id: entry.plugin.id,
                       state: .installed(version: version),
                       licenseState: newLicenseState)
            } catch {
                update(id: entry.plugin.id, state: .error(error.localizedDescription))
            }
        }
    }

    // MARK: - License actions

    func activateLicense(key: String, for plugin: Plugin) async throws {
        try await licenseManager.activateLicense(key: key, for: plugin.id)
        // Update the entry's license state.
        if let idx = entries.firstIndex(where: { $0.id == plugin.id }) {
            entries[idx].licenseState = .licensed
        }
        licenseActionPlugin = nil
    }

    func showLicenseSheet(for plugin: Plugin) {
        licenseActionPlugin = plugin
    }

    // MARK: - Private helpers

    private func resolveInstallStates(for plugins: [Plugin]) async -> [PluginEntry] {
        var result: [PluginEntry] = []

        for plugin in plugins {
            let installedStr = await engine.installedVersion(for: plugin)
            let state        = installState(installed: installedStr, remote: plugin.currentVersion)
            let licenseState = licenseManager.state(for: plugin.id)
            // Preserve an in-progress or error state from a previous entry.
            let preserved    = entries.first(where: { $0.id == plugin.id })?.installState
            result.append(PluginEntry(
                plugin:       plugin,
                installState: preserved?.shouldPreserve == true ? preserved! : state,
                licenseState: licenseState
            ))
        }

        return result
    }

    /// Determines install state using semantic version comparison.
    private func installState(installed: String?, remote: String) -> InstallState {
        guard let installed else { return .notInstalled }

        if let iv = SemanticVersion(installed), let rv = SemanticVersion(remote), iv < rv {
            return .updateAvailable(installedVersion: installed, remoteVersion: remote)
        }
        return .installed(version: installed)
    }

    private func update(id: String, state: InstallState, licenseState: LicenseState? = nil) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].installState = state
        if let licenseState {
            entries[idx].licenseState = licenseState
        }
    }
}

// MARK: - InstallState: preserve guard

private extension InstallState {
    /// True for transient states that should survive a feed refresh.
    var shouldPreserve: Bool {
        switch self {
        case .installing, .error: return true
        default:                  return false
        }
    }
}
