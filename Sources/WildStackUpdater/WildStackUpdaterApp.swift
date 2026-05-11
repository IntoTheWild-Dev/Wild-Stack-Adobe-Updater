import SwiftUI

@main
struct WildStackUpdaterApp: App {

    @StateObject private var store:   PluginStore
    @StateObject private var sparkle = SparkleUpdater()

    init() {
        let feedURL: URL? = {
            let args = CommandLine.arguments
            if let idx = args.firstIndex(of: "--local-feed"), idx + 1 < args.count {
                return URL(fileURLWithPath: args[idx + 1])
            }
            if let idx = args.firstIndex(of: "--feed-url"), idx + 1 < args.count {
                return URL(string: args[idx + 1])
            }
            return nil
        }()

        _store = StateObject(wrappedValue: PluginStore(feedURL: feedURL ?? PluginStore.defaultFeedURL))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(sparkle)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for App Updates…") {
                    sparkle.checkForUpdates()
                }
                .disabled(!sparkle.canCheckForUpdates)
            }
        }
    }
}
