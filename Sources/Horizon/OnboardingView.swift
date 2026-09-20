import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    private enum Step { case welcome, choose, lockdown, keys }
    @State private var step: Step = .welcome

    @State private var clientId = ""
    @State private var secret = ""
    @State private var apiKey = ""
    @State private var publicIP: String?
    @State private var lookingUpIP = false
    @State private var copied = false
    /// Whether the keys being entered are the public test ones.
    @State private var sandboxMode = false

    var body: some View {
        let accent = state.settings.accent.color

        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .welcome:
                GaugeMark(size: 30, color: accent)
                    .padding(.bottom, 12)
                Text("HORIZON")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(accent)
                Text("Your balance, and what it is about to do next.")
                    .font(.system(size: 19, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                Text("Horizon reads your Investec account and projects where your balance is heading, with the reasoning shown.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                primaryButton("Get started", accent: accent) { step = .choose }
                    .padding(.top, 18)

            case .choose:
                Text("CONNECT YOUR ACCOUNT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(accent)
                Text("Connect to Investec")
                    .font(.system(size: 19, weight: .semibold))
                    .padding(.top, 4)
                Text("Read only. Horizon never moves money, and your keys are stored in the macOS Keychain.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                choiceRow(
                    icon: "key.fill",
                    title: "Your Investec account",
                    detail: "Attach your own programmable banking API key.",
                    accent: accent
                ) { sandboxMode = false; step = .lockdown; lookUpIP() }

                choiceRow(
                    icon: "shield.lefthalf.filled",
                    title: "Investec sandbox",
                    detail: "Try it with the shared Mr Smith test account.",
                    accent: accent
                ) {
                    sandboxMode = true
                    state.clearError()
                    step = .keys
                }

                if let error = state.errorMessage {
                    errorBox(error)
                }

            case .lockdown:
                HStack(spacing: 4) {
                    Button { step = .choose } label: {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                        Text("Back").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)

                Text("LOCK IT TO THIS DEVICE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(accent)
                Text("Restrict the key to your IP")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 4)
                Text("Investec can limit an API key to specific IP addresses. Add the address below when you create the key, and it stops working from anywhere else, even if the key leaks.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                // The address to paste
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 12))
                        .foregroundStyle(accent)
                    Group {
                        if lookingUpIP {
                            Text("Looking up...").foregroundStyle(.tertiary)
                        } else if let ip = publicIP {
                            Text(ip).font(.system(size: 14, weight: .semibold, design: .monospaced))
                        } else {
                            Text("Could not determine").foregroundStyle(.tertiary)
                        }
                    }
                    .font(.system(size: 13))
                    Spacer(minLength: 4)
                    if let ip = publicIP {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(ip, forType: .string)
                            copied = true
                        } label: {
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 10.5, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    } else if !lookingUpIP {
                        Button { lookUpIP() } label: {
                            Text("Retry")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 4) {
                    stepLine("1", "Investec Online, then Manage, then Investec Developer.")
                    stepLine("2", "Open Individual Connections and create or edit your API key.")
                    stepLine("3", "Add the address above to the key's allowed IP addresses.")
                }
                .padding(.top, 12)

                Text("Heads up: if your network changes, a new office, mobile hotspot, or your ISP reassigning the address, update the allowlist or the key will be refused.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                primaryButton("I have set this up", accent: accent) { step = .keys }
                    .padding(.top, 12)

                Button { step = .keys } label: {
                    Text("Skip for now")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .center)

            case .keys:
                HStack(spacing: 4) {
                    Button { step = .choose; state.clearError() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                        Text("Back").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)

                Text(sandboxMode ? "SANDBOX KEYS" : "YOUR INVESTEC KEYS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(accent)
                Text(sandboxMode
                     ? "Investec publishes shared test keys in their developer documentation. Horizon does not ship them, so copy them across from there."
                     : "Investec Online, then Manage, Investec Developer, Individual Connections, Create new API key.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .padding(.bottom, sandboxMode ? 6 : 10)

                if sandboxMode {
                    Link(destination: URL(string: "https://developer.investec.com/za/api-products")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square").font(.system(size: 10))
                            Text("Open the Investec developer docs")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(accent)
                    }
                    .padding(.bottom, 10)
                }

                field("Client ID", text: $clientId, secure: false)
                field("Client secret", text: $secret, secure: true)
                field("API key", text: $apiKey, secure: true)

                if let error = state.errorMessage {
                    errorBox(error)
                }

                primaryButton("Connect securely", accent: accent) {
                    Task {
                        await state.connect(with: Credentials(
                            clientId: clientId.trimmingCharacters(in: .whitespaces),
                            secret: secret.trimmingCharacters(in: .whitespaces),
                            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
                            production: !sandboxMode
                        ))
                    }
                }
                .padding(.top, 12)
                .disabled(clientId.isEmpty || secret.isEmpty || apiKey.isEmpty)
                .opacity(clientId.isEmpty || secret.isEmpty || apiKey.isEmpty ? 0.5 : 1)
            }

            if state.loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Connecting to Investec...").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            }
        }
        .padding(18)
    }

    // MARK: - Pieces

    private func lookUpIP() {
        guard publicIP == nil, !lookingUpIP else { return }
        lookingUpIP = true
        copied = false
        Task {
            let found = await PublicIP.fetch()
            await MainActor.run {
                publicIP = found
                lookingUpIP = false
            }
        }
    }

    private func stepLine(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text(number)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 14, height: 14)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func field(_ label: String, text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))
        }
        .padding(.bottom, 8)
    }

    private func choiceRow(
        icon: String, title: String, detail: String, accent: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.system(size: 10.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
    }

    private func primaryButton(_ title: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }

    /// Explains what went wrong and what to check, rather than dumping a code.
    private func errorBox(_ message: String) -> some View {
        let accent = state.settings.accent.color
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.moneyOut)
                Text(message)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.moneyOut)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !state.errorHints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.errorHints, id: \.self) { hint in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").font(.system(size: 10)).foregroundStyle(.tertiary)
                            Text(hint)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // When it smells like the allowlist, put the address right here.
            if state.errorMightBeIP {
                Divider().padding(.vertical, 1)
                HStack(spacing: 7) {
                    Image(systemName: "network").font(.system(size: 11)).foregroundStyle(accent)
                    if let ip = publicIP {
                        Text(ip).font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    } else {
                        Text(lookingUpIP ? "Looking up your IP..." : "Your IP")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 4)
                    if let ip = publicIP {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(ip, forType: .string)
                            copied = true
                        } label: {
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    state.clearError()
                    step = .lockdown
                    lookUpIP()
                } label: {
                    Text("How to allowlist this address")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.moneyOut.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Palette.moneyOut.opacity(0.25), lineWidth: 1)
        )
        .padding(.top, 10)
        .onAppear { if state.errorMightBeIP { lookUpIP() } }
    }
}
