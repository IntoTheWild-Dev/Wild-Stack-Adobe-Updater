import Foundation

struct HostDetector {

    struct DetectedHost {
        let host: PluginHost
        let appURL: URL
        let version: String
    }

    // Returns only the hosts actually installed on this machine.
    static func detectAll() -> [PluginHost: DetectedHost] {
        var results: [PluginHost: DetectedHost] = [:]
        if let ae = detect(.aftereffects) { results[.aftereffects] = ae }
        if let id = detect(.indesign)     { results[.indesign]     = id }
        if let ps = detect(.photoshop)    { results[.photoshop]    = ps }
        return results
    }

    // MARK: - Private

    private static func detect(_ host: PluginHost) -> DetectedHost? {
        let prefix: String
        switch host {
        case .aftereffects: prefix = "Adobe After Effects"
        case .indesign:     prefix = "Adobe InDesign"
        case .photoshop:    prefix = "Adobe Photoshop"
        }

        let appBundles = findAppBundles(prefix: prefix)
        guard let appURL = appBundles.first else { return nil }
        let version = bundleVersion(at: appURL) ?? "unknown"
        return DetectedHost(host: host, appURL: appURL, version: version)
    }

    /// Scans /Applications and ~/Applications for app bundles matching `prefix`.
    /// Handles both:
    ///   - Direct .app bundles:  /Applications/Adobe Photoshop 2026.app
    ///   - Creative Cloud style: /Applications/Adobe Photoshop 2026/Adobe Photoshop 2026.app
    private static func findAppBundles(prefix: String) -> [URL] {
        let fm = FileManager.default
        let searchRoots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        var found: [URL] = []
        for root in searchRoots {
            guard let items = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in items {
                let name = item.lastPathComponent

                // Case 1: Direct .app bundle — "Adobe After Effects 2026.app"
                if name.hasSuffix(".app") {
                    let base = String(name.dropLast(4))
                    if base.hasPrefix(prefix) {
                        found.append(item)
                    }
                    continue
                }

                // Case 2: Creative Cloud wrapper folder — "Adobe After Effects 2026/"
                if name.hasPrefix(prefix), item.hasDirectoryPath {
                    if let nested = try? fm.contentsOfDirectory(
                        at: item,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        for nestedItem in nested {
                            let nestedName = nestedItem.lastPathComponent
                            if nestedName.hasSuffix(".app"),
                               String(nestedName.dropLast(4)).hasPrefix(prefix) {
                                found.append(nestedItem)
                            }
                        }
                    }
                }
            }
        }

        // Sort newest (highest year suffix) first.
        return found.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func bundleVersion(at appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard
            let plist = NSDictionary(contentsOf: plistURL),
            let version = plist["CFBundleShortVersionString"] as? String
        else { return nil }
        return version
    }
}
