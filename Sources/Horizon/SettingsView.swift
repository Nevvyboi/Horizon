import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Binding var screen: Screen
    @State private var confirmingDisconnect = false

    var body: some View {
        let accent = state.settings.accent.color

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { screen = .quick } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                            Text("Balance").font(.system(size: 11.5))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("Settings").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                .padding(.bottom, 14)

                // Appearance
                SectionLabel(text: "Appearance")
                Text("Background")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.top, 8)
                Picker("", selection: Binding(
                    get: { state.settings.appearance },
                    set: { state.settings.appearance = $0 }
                )) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.top, 6)

                Text("Accent colour")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.top, 8)
                HStack(spacing: 8) {
                    ForEach(Accent.all) { option in
                        Button {
                            state.settings.accentId = option.id
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(
                                        state.settings.accentId == option.id ? 0.9 : 0.12
                                    ), lineWidth: state.settings.accentId == option.id ? 2 : 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .opacity(state.settings.accentId == option.id ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(option.name)
                    }
                }
                .padding(.top, 8)

                Divider().padding(.vertical, 14)

                // Data
                SectionLabel(text: "Data")
                settingRow(
                    icon: "arrow.clockwise",
                    title: "Auto refresh",
                    detail: "Every \(state.settings.refreshMinutes) min"
                ) {
                    Stepper("", onIncrement: {
                        bumpRefresh(1)
                    }, onDecrement: {
                        bumpRefresh(-1)
                    })
                    .labelsHidden()
                }

                settingRow(
                    icon: "menubar.rectangle",
                    title: "Show balance in menu bar",
                    detail: state.settings.requireUnlock
                        ? "Hidden while locking is on"
                        : (state.settings.showBalanceInMenuBar ? "On" : "Off")
                ) {
                    Toggle("", isOn: Binding(
                        get: { state.settings.showBalanceInMenuBar },
                        set: { state.settings.showBalanceInMenuBar = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(state.settings.requireUnlock)
                }
                .opacity(state.settings.requireUnlock ? 0.5 : 1)

                settingRow(
                    icon: "power",
                    title: "Launch at login",
                    detail: state.settings.launchAtLogin ? "On" : "Off"
                ) {
                    Toggle("", isOn: Binding(
                        get: { state.settings.launchAtLogin },
                        set: { state.settings.launchAtLogin = $0; LoginItem.set($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                Divider().padding(.vertical, 14)

                // Privacy
                SectionLabel(text: "Privacy")
                settingRow(
                    icon: "lock",
                    title: "Lock when closed",
                    detail: state.settings.requireUnlock
                        ? "Ask for \(Unlock.methodDescription.lowercased())"
                        : "Off, opens straight to your balance"
                ) {
                    Toggle("", isOn: Binding(
                        get: { state.settings.requireUnlock },
                        set: { on in
                            state.settings.requireUnlock = on
                            // Switching it on should take hold now, not on
                            // the next visit. Switching it off lets the
                            // current window through without a prompt.
                            if on { state.lock() } else { state.unlocked = true }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                if state.settings.requireUnlock {
                    Text("The menu bar opens on a single click, so anyone passing an unlocked laptop can read your balance. With this on, Horizon asks who you are every time the window closes and opens again, and keeps the balance out of the menu bar too, since guarding the window while printing the number above it would protect nothing.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Divider().padding(.vertical, 14)

                // Balance
                SectionLabel(text: "Balance")
                settingRow(
                    icon: "creditcard",
                    title: "Balance includes credit",
                    detail: state.settings.balanceIncludesCredit
                        ? "Taking \(Money.short(state.settings.creditFacility)) back out"
                        : "Reported balance used as is"
                ) {
                    Toggle("", isOn: Binding(
                        get: { state.settings.balanceIncludesCredit },
                        set: { state.settings.balanceIncludesCredit = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                if state.settings.balanceIncludesCredit {
                    settingRow(
                        icon: "banknote",
                        title: "Facility size",
                        detail: "What the bank lends you, not your own money"
                    ) {
                        HStack(spacing: 2) {
                            Text("R").font(.system(size: 11)).foregroundStyle(.secondary)
                            TextField("0", value: Binding(
                                get: { state.settings.creditFacility },
                                set: { state.settings.creditFacility = max(0, $0) }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .frame(width: 74)
                        }
                    }

                    Text("Some accounts report one balance with the overdraft already counted in it, so money you have borrowed looks like money you have. Turning this on subtracts the facility, leaving what is actually yours, and the forecast then measures how close you are to the bottom of the facility instead of to zero.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Divider().padding(.vertical, 14)

                // Account
                SectionLabel(text: "Account")
                if let account = state.account {
                    settingRow(icon: "building.columns", title: account.name,
                               detail: state.usingProduction ? "Investec account" : "Investec sandbox") {
                        EmptyView()
                    }
                    settingRow(icon: "list.bullet", title: "Transactions read",
                               detail: "\(state.transactions.count)") { EmptyView() }
                }

                Text("Read only. Horizon never moves money. Your keys are stored in the macOS Keychain, never in the app bundle. Forecasts are estimates, not guarantees, and not financial advice.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Divider().padding(.vertical, 14)

                Button {
                    if confirmingDisconnect {
                        state.disconnect()
                        screen = .quick
                    } else {
                        confirmingDisconnect = true
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "xmark.circle").font(.system(size: 11))
                        Text(confirmingDisconnect ? "Tap again to confirm" : "Disconnect and remove data")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Palette.moneyOut)
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "power").font(.system(size: 11))
                        Text("Quit Horizon").font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .scrollIndicators(.never)
        .frame(height: 520)
        .tint(accent)
    }

    private func bumpRefresh(_ direction: Int) {
        let choices = Settings.refreshChoices
        let index = choices.firstIndex(of: state.settings.refreshMinutes) ?? 2
        let next = min(choices.count - 1, max(0, index + direction))
        state.settings.refreshMinutes = choices[next]
        state.scheduleRefresh()
    }

    @ViewBuilder
    private func settingRow<Trailing: View>(
        icon: String, title: String, detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                Text(detail).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.vertical, 5)
    }
}

/// Launch at login, using the modern SMAppService API.
enum LoginItem {
    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Not fatal: the toggle simply will not stick.
        }
    }
}
