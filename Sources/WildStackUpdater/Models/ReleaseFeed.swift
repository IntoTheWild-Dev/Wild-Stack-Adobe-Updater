import Foundation

// Matches the JSON published to GitHub Pages / GitHub Releases.
// See Resources/release-feed.example.json for the full schema.

struct ReleaseFeed: Codable {
    let feedVersion: Int
    let updatedAt: String
    let plugins: [RemotePlugin]
}

struct RemotePlugin: Codable {
    let id: String
    let name: String
    let description: String
    let host: String            // "aftereffects" | "indesign"
    let currentVersion: String
    let minimumHostVersion: String
    let downloadURL: String
    let sha256: String
    let releaseNotes: String
}
