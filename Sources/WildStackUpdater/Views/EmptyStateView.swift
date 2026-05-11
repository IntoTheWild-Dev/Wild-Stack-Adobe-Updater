import SwiftUI

struct EmptyStateView: View {
    let isLoading: Bool
    let error: String?

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .tint(WDS.slate)
                Text("Checking for plugins…")
                    .font(WDS.inter(13))
                    .foregroundStyle(WDS.muted)

            } else if let error {
                icon("exclamationmark.triangle", color: WDS.amber)
                Text("Could not load plugins")
                    .font(WDS.inter(14, weight: .semibold))
                    .foregroundStyle(WDS.heading)
                Text(error)
                    .font(WDS.inter(12))
                    .foregroundStyle(WDS.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

            } else {
                icon("puzzlepiece.extension", color: WDS.slate)
                Text("No plugins found")
                    .font(WDS.inter(14, weight: .semibold))
                    .foregroundStyle(WDS.heading)
                Text("Check your connection or refresh to try again.")
                    .font(WDS.inter(12))
                    .foregroundStyle(WDS.muted)
            }
        }
        .padding(32)
    }

    private func icon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 28, weight: .light))
            .foregroundStyle(color.opacity(0.7))
    }
}
