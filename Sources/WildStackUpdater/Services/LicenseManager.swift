import Foundation

@MainActor
final class LicenseManager: ObservableObject {

    @Published private(set) var trialStates: [String: Bool] = [:]
    @Published private(set) var licenseKeys: [String: String] = [:]

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let trialPrefix   = "WildStack.license.trial.used."
        static let licensePrefix = "WildStack.license.key."
        static let purchaseURL   = "WildStack.license.purchaseURL"
        static let validationURL = "WildStack.license.validationURL"
        static let machineID     = "WildStack.license.machineID"
        static let agencyKey     = "WildStack.license.agencyKey"
    }

    nonisolated static let defaultPurchaseURL = URL(
        string: "https://intothewild.dev/purchase"
    )!

    private var machineID: String {
        if let existing = defaults.string(forKey: Keys.machineID) {
            return existing
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: Keys.machineID)
        return id
    }

    init() {
        loadCachedState()
    }

    // MARK: - Trial

    func trialUsed(for pluginID: String) -> Bool {
        defaults.bool(forKey: Keys.trialPrefix + pluginID)
    }

    func markTrialUsed(for pluginID: String) {
        defaults.set(true, forKey: Keys.trialPrefix + pluginID)
        trialStates[pluginID] = true
    }

    // MARK: - Agency override

    /// When set, bypasses all trial limits and license checks across every plugin.
    func setAgencyKey(_ key: String) {
        defaults.set(key, forKey: Keys.agencyKey)
    }

    func clearAgencyKey() {
        defaults.removeObject(forKey: Keys.agencyKey)
    }

    var isAgencyUnlocked: Bool {
        guard let key = defaults.string(forKey: Keys.agencyKey) else { return false }
        return !key.isEmpty
    }

    // MARK: - License

    func isLicensed(for pluginID: String) -> Bool {
        guard let key = licenseKey(for: pluginID) else { return false }
        return !key.isEmpty
    }

    func licenseKey(for pluginID: String) -> String? {
        defaults.string(forKey: Keys.licensePrefix + pluginID)
    }

    func state(for pluginID: String) -> LicenseState {
        if isAgencyUnlocked          { return .licensed }
        if isLicensed(for: pluginID) { return .licensed }
        if trialUsed(for: pluginID)  { return .trialUsed }
        return .trialAvailable
    }

    // MARK: - Activate

    func activateLicense(key: String, for pluginID: String) async throws {
        guard key.count >= 8 else {
            throw LicenseError.invalidFormat
        }

        // If a validation server URL is configured, validate remotely.
        if let validationURL = validationServerURL {
            let valid = try await validateRemotely(key: key, pluginID: pluginID, at: validationURL)
            guard valid else { throw LicenseError.invalidKey }
        }

        // Store locally.
        defaults.set(key, forKey: Keys.licensePrefix + pluginID)
        licenseKeys[pluginID] = key
    }

    func deactivateLicense(for pluginID: String) {
        defaults.removeObject(forKey: Keys.licensePrefix + pluginID)
        licenseKeys.removeValue(forKey: pluginID)
    }

    // MARK: - Purchase URL

    var purchaseURL: URL {
        if let str = defaults.string(forKey: Keys.purchaseURL),
           let url = URL(string: str) {
            return url
        }
        return Self.defaultPurchaseURL
    }

    func setPurchaseURL(_ url: URL) {
        defaults.set(url.absoluteString, forKey: Keys.purchaseURL)
    }

    // MARK: - Validation server URL

    var validationServerURL: URL? {
        guard let str = defaults.string(forKey: Keys.validationURL) else { return nil }
        return URL(string: str)
    }

    func setValidationServerURL(_ url: URL?) {
        if let url {
            defaults.set(url.absoluteString, forKey: Keys.validationURL)
        } else {
            defaults.removeObject(forKey: Keys.validationURL)
        }
    }

    // MARK: - Private

    private func loadCachedState() {
        _ = machineID // ensure machine ID is generated
    }

    private func validateRemotely(key: String, pluginID: String, at url: URL) async throws -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = [
            "licenseKey": key,
            "pluginId": pluginID,
            "machineId": machineID,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LicenseError.serverUnreachable
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let valid = json["valid"] as? Bool
        else {
            throw LicenseError.invalidResponse
        }

        return valid
    }
}

// MARK: - Errors

extension LicenseManager {
    enum LicenseError: LocalizedError {
        case invalidFormat
        case invalidKey
        case serverUnreachable
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidFormat:    return "License key must be at least 8 characters."
            case .invalidKey:       return "This license key is not valid. Please check and try again."
            case .serverUnreachable: return "Could not reach the license server. Check your connection."
            case .invalidResponse:  return "Unexpected response from license server."
            }
        }
    }
}
