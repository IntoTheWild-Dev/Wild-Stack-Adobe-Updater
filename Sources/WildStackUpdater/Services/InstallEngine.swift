import Foundation
import CryptoKit

actor InstallEngine {

    // MARK: - Errors

    enum InstallError: LocalizedError {
        case checksumMismatch
        case extractionFailed
        case noContentFound
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .checksumMismatch:      return "Checksum mismatch — the download may be corrupted."
            case .extractionFailed:      return "Could not extract the plugin archive."
            case .noContentFound:        return "Archive contained no recognisable plugin content."
            case .copyFailed(let msg):   return "Could not copy plugin: \(msg)"
            }
        }
    }

    // MARK: - Install

    /// Downloads, verifies, extracts, and copies `plugin` to its Adobe folder.
    /// `onProgress` is dispatched to the main actor and reports 0.0 → 1.0.
    func install(
        plugin: Plugin,
        onProgress: @MainActor @escaping (Double) -> Void
    ) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // ── 1. Download (reports 0.05 → 0.45 with real byte progress) ──────
        await onProgress(0.02)
        let zipURL = try await download(from: plugin.downloadURL) { fraction in
            await onProgress(0.05 + fraction * 0.40)
        }
        // Move into our managed tempDir so defer cleans it up.
        let managedZip = tempDir.appendingPathComponent("\(plugin.id).zip")
        try FileManager.default.moveItem(at: zipURL, to: managedZip)
        await onProgress(0.46)

        // ── 2. SHA-256 checksum ────────────────────────────────────────────
        if !isPlaceholderSHA(plugin.sha256) {
            let data   = try Data(contentsOf: managedZip)
            let digest = SHA256.hash(data: data)
            let hex    = digest.map { String(format: "%02x", $0) }.joined()
            guard hex == plugin.sha256 else { throw InstallError.checksumMismatch }
        }
        await onProgress(0.55)

        // ── 3. Extract ─────────────────────────────────────────────────────
        let extractDir = tempDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try await unzip(managedZip, to: extractDir)
        await onProgress(0.78)

        // ── 4. Copy to Adobe folder ────────────────────────────────────────
        try copyToAdobeFolder(from: extractDir, plugin: plugin)
        await onProgress(1.00)
    }

    // MARK: - Installed-version detection

    /// Returns the on-disk version string, or nil if the plugin is not installed.
    func installedVersion(for plugin: Plugin) -> String? {
        switch plugin.host {
        case .aftereffects: return cepVersion(pluginID: plugin.id)
        case .indesign,
             .photoshop:    return uxpVersion(pluginID: plugin.id, at: plugin.host.installDirectory)
        }
    }

    // MARK: - Private: download with real progress

    private func download(
        from url: URL,
        onProgress: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let delegate = DownloadDelegate(
                progressHandler: { written, total in
                    let fraction = Double(written) / Double(total)
                    Task { await onProgress(fraction) }
                },
                completionHandler: { result in
                    cont.resume(with: result)
                }
            )
            let session = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )
            delegate.ownedSession = session   // retain cycle resolves on completion
            session.downloadTask(with: url).resume()
        }
    }

    // MARK: - Private: unzip

    private func unzip(_ zipURL: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            proc.arguments     = ["-o", "-q", zipURL.path, "-d", destination.path]
            proc.terminationHandler = { p in
                p.terminationStatus == 0
                    ? cont.resume()
                    : cont.resume(throwing: InstallError.extractionFailed)
            }
            do    { try proc.run() }
            catch { cont.resume(throwing: error) }
        }
    }

    // MARK: - Private: copy to Adobe folder

    private func copyToAdobeFolder(from extractDir: URL, plugin: Plugin) throws {
        let fm          = FileManager.default
        let destination = plugin.host.installDirectory

        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let items = try fm.contentsOfDirectory(
            at: extractDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        // Filter macOS archive artifacts (__MACOSX, .DS_Store wrappers etc.)
        .filter { !$0.lastPathComponent.hasPrefix("__") }

        guard let source = items.first(where: \.hasDirectoryPath) ?? items.first else {
            throw InstallError.noContentFound
        }

        let target = destination.appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: target.path) {
            try fm.removeItem(at: target)
        }
        do {
            try fm.copyItem(at: source, to: target)
        } catch {
            throw InstallError.copyFailed(error.localizedDescription)
        }
    }

    // MARK: - Private: version readers

    /// Reads CEP `manifest.xml` to find the installed bundle version.
    private func cepVersion(pluginID: String) -> String? {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(
            at: PluginHost.aftereffects.installDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for folder in folders {
            let manifestURL = folder.appendingPathComponent("CSXS/manifest.xml")
            guard
                let content = try? String(contentsOf: manifestURL, encoding: .utf8),
                content.contains(pluginID)
            else { continue }

            // Match: ExtensionBundleId="com.wildagency.aestackcompswap" ... ExtensionBundleVersion="1.2.3"
            let pattern = #"ExtensionBundleVersion="([^"]+)""#
            if let range = content.range(of: pattern, options: .regularExpression) {
                let parts = String(content[range]).components(separatedBy: "\"")
                if parts.count >= 2 { return parts[1] }
            }
        }
        return nil
    }

    /// Reads UXP `manifest.json` to find the installed plugin version.
    private func uxpVersion(pluginID: String, at directory: URL) -> String? {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for folder in folders {
            let manifestURL = folder.appendingPathComponent("manifest.json")
            guard
                let data    = try? Data(contentsOf: manifestURL),
                let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let id      = json["id"] as? String, id == pluginID,
                let version = json["version"] as? String
            else { continue }
            return version
        }
        return nil
    }

    // MARK: - Private: helpers

    /// Skips checksum verification for unset placeholder values during development.
    private func isPlaceholderSHA(_ sha: String) -> Bool {
        sha.isEmpty || sha.uppercased().hasPrefix("REPLACE")
    }
}

// MARK: - URLSession download delegate (bridges delegate callbacks to async/await)

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    typealias ProgressHandler    = @Sendable (Int64, Int64) -> Void
    typealias CompletionHandler  = @Sendable (Result<URL, Error>) -> Void

    private let progressHandler:   ProgressHandler
    private let completionHandler: CompletionHandler
    private var didFinish = false

    /// Retaining the session here creates a deliberate cycle that breaks on completion.
    var ownedSession: URLSession?

    init(progressHandler: @escaping ProgressHandler, completionHandler: @escaping CompletionHandler) {
        self.progressHandler   = progressHandler
        self.completionHandler = completionHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progressHandler(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        didFinish = true
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            completionHandler(.success(dest))
        } catch {
            completionHandler(.failure(error))
        }
        ownedSession = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, !didFinish else { return }
        completionHandler(.failure(error))
        ownedSession = nil
    }
}
