import SwiftUI

struct LicenseSheetView: View {
    let plugin: Plugin
    let purchaseURL: URL
    let onActivate: (String) async throws -> Void
    let onDismiss: () -> Void

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(WDS.input)
                .frame(width: 32, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header
            VStack(spacing: 6) {
                Image(systemName: plugin.host.systemIcon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(WDS.slate)

                Text("Activate \(plugin.name)")
                    .font(WDS.inter(16, weight: .semibold))
                    .foregroundStyle(WDS.heading)

                Text("Enter your license key to unlock this plugin.")
                    .font(WDS.inter(12))
                    .foregroundStyle(WDS.muted)
            }
            .padding(.bottom, 20)

            // License key field
            VStack(alignment: .leading, spacing: 6) {
                Text("License Key")
                    .font(WDS.inter(11, weight: .medium))
                    .foregroundStyle(WDS.muted)

                TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(WDS.inter(14, weight: .medium))
                    .foregroundStyle(WDS.heading)
                    .focused($isKeyFieldFocused)
                    .padding(10)
                    .background(WDS.input)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isKeyFieldFocused ? WDS.slate : WDS.input, lineWidth: 1)
                    )
                    .disabled(isActivating || showSuccess)
            }
            .padding(.bottom, 8)

            // Error message
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(WDS.coral)
                    Text(error)
                        .font(WDS.inter(11))
                        .foregroundStyle(WDS.coral)
                }
                .padding(.bottom, 10)
            }

            // Success check
            if showSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(WDS.success)
                    Text("License activated!")
                        .font(WDS.inter(13, weight: .medium))
                        .foregroundStyle(WDS.success)
                }
                .padding(.bottom, 10)
            }

            // Activate button
            Button {
                Task { await activate() }
            } label: {
                HStack(spacing: 6) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(isActivating ? "Activating…" : "Activate License")
                        .font(WDS.inter(14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    licenseKey.count >= 8 && !isActivating && !showSuccess
                        ? WDS.ctaGradient
                        : LinearGradient(
                            colors: [WDS.slate.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(licenseKey.count < 8 || isActivating || showSuccess)
            .padding(.bottom, 16)

            // Purchase link
            HStack(spacing: 4) {
                Text("Don't have a license?")
                    .font(WDS.inter(11))
                    .foregroundStyle(WDS.muted)

                Button {
                    NSWorkspace.shared.open(purchaseURL)
                } label: {
                    Text("Buy License")
                        .font(WDS.inter(11, weight: .semibold))
                        .foregroundStyle(WDS.amber)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(WDS.card)
        .onAppear { isKeyFieldFocused = true }
    }

    private func activate() async {
        isActivating = true
        errorMessage = nil

        do {
            try await onActivate(licenseKey)
            showSuccess = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isActivating = false
    }
}
