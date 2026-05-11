import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: PluginStore
    @EnvironmentObject var sparkle: SparkleUpdater

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            pluginList
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 380)
        .background(WDS.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar { toolbarContent }
        .sheet(item: $store.licenseActionPlugin) { plugin in
            LicenseSheetView(
                plugin: plugin,
                purchaseURL: store.purchaseURL,
                onActivate: { key in
                    try await store.activateLicense(key: key, for: plugin)
                },
                onDismiss: {
                    store.licenseActionPlugin = nil
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                // Wordmark
                HStack(spacing: 0) {
                    Text("Wild Stack")
                        .font(WDS.inter(17, weight: .bold))
                        .foregroundStyle(WDS.heading)
                    Text(" Updater")
                        .font(WDS.inter(17, weight: .bold))
                        .foregroundStyle(WDS.coral)
                }

                // Detected host apps
                hostLine
            }

            Spacer()

            // Version pill — matches BETA badge pattern from plugin screenshot
            Text("v1.0")
                .font(WDS.inter(10, weight: .medium))
                .foregroundStyle(WDS.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(WDS.input)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(WDS.bg)
    }

    @ViewBuilder
    private var hostLine: some View {
        let detected = store.detectedHosts.keys
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)

        if detected.isEmpty {
            Text("No Adobe host apps detected")
                .font(WDS.inter(11))
                .foregroundStyle(WDS.muted)
        } else {
            HStack(spacing: 6) {
                ForEach(detected, id: \.self) { name in
                    hostPill(name)
                }
            }
        }
    }

    private func hostPill(_ name: String) -> some View {
        Text(name)
            .font(WDS.inter(10, weight: .medium))
            .foregroundStyle(WDS.slate)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(WDS.input)
            .clipShape(Capsule())
    }

    private var divider: some View {
        Rectangle()
            .fill(WDS.input)
            .frame(height: 1)
    }

    // MARK: - Plugin list

    @ViewBuilder
    private var pluginList: some View {
        if store.entries.isEmpty {
            EmptyStateView(isLoading: store.isLoading, error: store.feedError)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WDS.bg)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.entries) { entry in
                        PluginCardView(
                            entry: entry,
                            hostDetected: store.detectedHosts[entry.plugin.host] != nil,
                            onInstall: {
                                store.install(entry: entry)
                            },
                            onActivateLicense: {
                                store.showLicenseSheet(for: entry.plugin)
                            }
                        )
                    }
                }
                .padding(14)
            }
            .background(WDS.bg)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WDS.muted)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(WDS.muted)
                }
            }
            .disabled(store.isLoading)
            .help("Refresh plugin list")
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
