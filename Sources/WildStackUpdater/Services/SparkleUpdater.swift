import Sparkle
import Combine

/// Thin ObservableObject wrapper around Sparkle so SwiftUI views can bind to it.
final class SparkleUpdater: NSObject, ObservableObject {

    private let controller: SPUStandardUpdaterController
    private var cancellable: AnyCancellable?

    @Published private(set) var canCheckForUpdates = false

    override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        // Bridge Sparkle's KVO property into Combine / SwiftUI.
        cancellable = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: \.canCheckForUpdates, on: self)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
