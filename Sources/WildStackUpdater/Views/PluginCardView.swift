import SwiftUI

struct PluginCardView: View {
    let entry: PluginEntry
    let hostDetected: Bool
    let onInstall: () -> Void
    let onActivateLicense: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            hostIcon
            info
            Spacer(minLength: 8)
            actionArea
        }
        .padding(14)
        .background(WDS.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(WDS.input, lineWidth: 1)
        )
    }

    // MARK: - Host icon block

    private var hostIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(WDS.input)
                .frame(width: 44, height: 44)

            Image(systemName: entry.plugin.host.systemIcon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(WDS.slate)
        }
    }

    // MARK: - Info column

    private var info: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.plugin.name)
                .font(WDS.inter(14, weight: .semibold))
                .foregroundStyle(WDS.heading)
                .lineLimit(1)

            Text(entry.plugin.description)
                .font(WDS.inter(12))
                .foregroundStyle(WDS.muted)
                .lineLimit(1)

            statusBadge
        }
    }

    // MARK: - Status badge

    @ViewBuilder
    private var statusBadge: some View {
        switch entry.installState {

        case .notInstalled:
            licenseLabel

        case .installed(let v):
            HStack(spacing: 4) {
                Circle()
                    .fill(WDS.success)
                    .frame(width: 5, height: 5)
                Text(v)
                    .font(WDS.inter(11))
                    .foregroundStyle(WDS.success)
            }

        case .updateAvailable(let iv, let rv):
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(WDS.amber)
                Text("\(iv) → \(rv)")
                    .font(WDS.inter(11))
                    .foregroundStyle(WDS.amber)
            }

        case .installing(let p):
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                    .tint(WDS.coral)
                    .frame(maxWidth: 160)
                Text("Installing…")
                    .font(WDS.inter(10))
                    .foregroundStyle(WDS.muted)
            }

        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(WDS.coral)
                Text(msg)
                    .font(WDS.inter(11))
                    .foregroundStyle(WDS.coral)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var licenseLabel: some View {
        switch entry.licenseState {
        case .trialAvailable:
            HStack(spacing: 4) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(WDS.amber)
                Text("1 free trial available")
                    .font(WDS.inter(11))
                    .foregroundStyle(WDS.amber)
            }
        case .trialUsed:
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(WDS.coral)
                Text("Trial used")
                    .font(WDS.inter(11))
                    .foregroundStyle(WDS.coral)
            }
        case .licensed:
            Text("Not installed")
                .font(WDS.inter(11))
                .foregroundStyle(WDS.muted)
        }
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        if !hostDetected {
            Text(entry.plugin.host.displayName + "\nnot found")
                .font(WDS.inter(10))
                .foregroundStyle(WDS.muted.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(width: 72)
        } else {
            switch entry.installState {

            case .notInstalled:
                notInstalledAction

            case .updateAvailable:
                if entry.licenseState.canInstall {
                    gradientButton(label: "Update", action: onInstall)
                } else {
                    activateButton
                }

            case .installed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(WDS.success)
                    .frame(width: 72)

            case .installing(let p):
                ZStack {
                    if p >= 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(WDS.success)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(WDS.coral)
                    }
                }
                .frame(width: 72)

            case .error:
                outlineButton(label: "Retry", color: WDS.coral, action: onInstall)
            }
        }
    }

    @ViewBuilder
    private var notInstalledAction: some View {
        switch entry.licenseState {
        case .trialAvailable:
            gradientButton(label: "Try Free", action: onInstall)
        case .trialUsed:
            activateButton
        case .licensed:
            gradientButton(label: "Install", action: onInstall)
        }
    }

    private var activateButton: some View {
        outlineButton(label: "Activate", color: WDS.amber, action: onActivateLicense)
    }

    // MARK: - Button helpers

    private func gradientButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(WDS.inter(12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 30)
                .background(WDS.ctaGradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func outlineButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(WDS.inter(12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 72, height: 30)
                .background(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
