import Foundation

// MARK: - Plugin Host

enum PluginHost: String, Codable, CaseIterable, Hashable {
    case aftereffects
    case indesign
    case photoshop

    var displayName: String {
        switch self {
        case .aftereffects: return "After Effects"
        case .indesign:     return "InDesign"
        case .photoshop:    return "Photoshop"
        }
    }

    var systemIcon: String {
        switch self {
        case .aftereffects: return "film"
        case .indesign:     return "doc.richtext"
        case .photoshop:    return "camera.filters"
        }
    }

    /// Where the plugin lives on disk after installation.
    var installDirectory: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        switch self {
        case .aftereffects:
            // CEP extensions directory
            return appSupport.appendingPathComponent("Adobe/CEP/extensions", isDirectory: true)
        case .indesign:
            // UXP plugins storage for InDesign
            return appSupport.appendingPathComponent("Adobe/UXP/PluginsStorage/IDSN", isDirectory: true)
        case .photoshop:
            // UXP extensions directory for Photoshop
            return appSupport.appendingPathComponent("Adobe/UXP/extensions", isDirectory: true)
        }
    }

    /// Whether this host uses UXP (manifest.json) rather than CEP (manifest.xml).
    var isUXP: Bool {
        switch self {
        case .aftereffects: return false
        case .indesign,
             .photoshop:    return true
        }
    }
}

// MARK: - Install State

enum InstallState: Equatable {
    case notInstalled
    case installed(version: String)
    case updateAvailable(installedVersion: String, remoteVersion: String)
    case installing(progress: Double)
    case error(String)

    var isIdle: Bool {
        switch self {
        case .installing: return false
        default:          return true
        }
    }

    var statusLabel: String {
        switch self {
        case .notInstalled:                              return "Not installed"
        case .installed(let v):                          return "Installed \(v)"
        case .updateAvailable(let iv, let rv):           return "\(iv) → \(rv)"
        case .installing:                                return "Installing…"
        case .error(let msg):                            return msg
        }
    }
}

// MARK: - Plugin

struct Plugin: Identifiable, Hashable {
    let id: String                  // e.g. "com.wildagency.aestackcompswap"
    let name: String
    let description: String
    let host: PluginHost
    let currentVersion: String      // Latest version on the remote feed
    let minimumHostVersion: String
    let downloadURL: URL
    let sha256: String
    let releaseNotes: String
}

// MARK: - Plugin Entry (Plugin + mutable UI state)

struct PluginEntry: Identifiable {
    var id: String { plugin.id }
    let plugin: Plugin
    var installState: InstallState
    var licenseState: LicenseState
}
