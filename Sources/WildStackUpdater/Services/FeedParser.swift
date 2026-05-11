import Foundation

struct FeedParser {
    let feedURL: URL

    // MARK: - Errors

    enum FeedError: LocalizedError {
        case httpError(Int)
        case decodingFailed(String)
        case networkUnavailable

        var errorDescription: String? {
            switch self {
            case .httpError(let code):      return "Feed request failed (HTTP \(code))."
            case .decodingFailed(let msg):  return "Could not parse the release feed: \(msg)"
            case .networkUnavailable:       return "No network connection. Showing cached data."
            }
        }
    }

    // MARK: - Fetch (network + auto-cache)

    /// Fetches the remote feed, saves it to disk cache, and returns parsed plugins.
    func fetch() async throws -> [Plugin] {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(from: feedURL)
        } catch {
            throw FeedError.networkUnavailable
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FeedError.httpError(http.statusCode)
        }

        let plugins = try decode(data)

        // Persist to disk so offline refreshes still return data.
        saveCache(data)

        return plugins
    }

    // MARK: - Cache fallback

    /// Returns the last successfully cached plugins, or nil if the cache is empty/corrupt.
    func fetchCached() -> [Plugin]? {
        guard
            let url  = cacheURL,
            let data = try? Data(contentsOf: url)
        else { return nil }

        return try? decode(data)
    }

    // MARK: - Private

    private func decode(_ data: Data) throws -> [Plugin] {
        // JSON is authored in camelCase — no key decoding strategy needed.
        let decoder = JSONDecoder()

        let feed: ReleaseFeed
        do {
            feed = try decoder.decode(ReleaseFeed.self, from: data)
        } catch {
            throw FeedError.decodingFailed(error.localizedDescription)
        }

        return feed.plugins.compactMap { remote in
            guard
                let host = PluginHost(rawValue: remote.host),
                let url  = URL(string: remote.downloadURL)
            else { return nil }

            return Plugin(
                id:                 remote.id,
                name:               remote.name,
                description:        remote.description,
                host:               host,
                currentVersion:     remote.currentVersion,
                minimumHostVersion: remote.minimumHostVersion,
                downloadURL:        url,
                sha256:             remote.sha256,
                releaseNotes:       remote.releaseNotes
            )
        }
    }

    private var cacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.wildagency.WildStackUpdater/release-feed.json")
    }

    private func saveCache(_ data: Data) {
        guard let url = cacheURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
