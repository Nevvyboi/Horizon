import SwiftUI

enum Screen {
    case quick, future, settings
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var screen: Screen = .quick

    var body: some View {
        Group {
            if !state.connected {
                OnboardingView()
            } else {
                switch screen {
                case .quick:    QuickView(screen: $screen)
                case .future:   FutureView(screen: $screen)
                case .settings: SettingsView(screen: $screen)
                }
            }
        }
        .frame(width: 340)
        .preferredColorScheme(state.settings.colorScheme)
        .animation(.easeInOut(duration: 0.22), value: screen)
        .animation(.easeInOut(duration: 0.25), value: state.connected)
    }
}

struct QuickView: View {
    @EnvironmentObject var state: AppState
    @Binding var screen: Screen
    @State private var monthView = true
    @State private var showCalendar = false

    var body: some View {
        let accent = state.settings.accent.color

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    HStack(spacing: 6) {
                        GaugeMark(size: 15, color: accent)
                        Text("Horizon").font(.system(size: 12, weight: .semibold))
                    }
                    Spacer()
                    Button { Task { await state.refresh() } } label: {
                        if state.loading {
                            ProgressView().controlSize(.mini).scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Refresh now")
                    Button { screen = .settings } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 14)

                if let forecast = state.forecast, let glance = state.glance {

                    // Balance. On a credit account this is what you actually
                    // hold, which can be negative, not the borrowed headroom.
                    let bal = state.balance
                    SectionLabel(text: (bal?.facility ?? 0) > 0 ? "Your balance" : "Available balance")
                    Text(Money.short(forecast.startBalance))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(forecast.startBalance < 0 ? Palette.moneyOut : .primary)
                        .padding(.top, 4)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Palette.outlook(forecast.outlook))
                            .frame(width: 6, height: 6)
                        Text(forecast.outlook.label)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)

                    if let bal, bal.facility > 0 {
                        balanceNote(
                            icon: "creditcard",
                            text: bal.usingCredit
                                ? "\(Money.short(abs(bal.settled))) into a \(Money.short(bal.facility)) facility, \(Money.short(bal.spendable)) left"
                                : "\(Money.short(bal.facility)) credit facility unused, \(Money.short(bal.spendable)) spendable"
                        )
                    }

                    // Money already spent that the bank has not posted yet.
                    // Some merchants only claim their card swipes once a week,
                    // so this can sit here for days looking like money you
                    // still have.
                    if let bal, bal.hasPending {
                        balanceNote(
                            icon: "clock.arrow.circlepath",
                            text: "\(Money.short(abs(bal.pending))) \(bal.pending < 0 ? "spent but not posted yet" : "incoming but not posted yet"), already counted above"
                        )
                    }

                    // Gauges
                    HStack(spacing: 6) {
                        GaugeRing(
                            value: glance.bufferFraction,
                            center: "\(Int(glance.bufferFraction * 100))%",
                            label: "Buffer",
                            sub: forecast.outlook.label,
                            color: Palette.outlook(forecast.outlook)
                        )
                        GaugeRing(
                            value: glance.payCycleProgress,
                            center: glance.daysToPayday.map { "\($0)d" } ?? "-",
                            label: "Payday",
                            sub: "until income",
                            color: Palette.moneyIn
                        )
                        GaugeRing(
                            value: glance.spentFraction,
                            center: "\(Int(glance.spentFraction * 100))%",
                            label: "Spent",
                            sub: "of typical",
                            color: glance.spentFraction > 0.9 ? Palette.moneyOut : accent
                        )
                    }
                    .padding(.vertical, 14)

                    // This month
                    card {
                        HStack {
                            SectionLabel(text: "This month")
                            Spacer()
                            Picker("", selection: $monthView) {
                                Text("Month").tag(true)
                                Text("Day").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 110)
                            .controlSize(.mini)
                        }
                        if monthView {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(Money.short(glance.spentThisMonth))
                                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text("of ~\(Money.short(glance.typicalMonthly)) typical")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                            ProgressView(value: glance.spentFraction)
                                .tint(glance.spentFraction > 0.9 ? Palette.moneyOut : accent)
                                .padding(.top, 4)
                        } else {
                            let perDay = glance.spentThisMonth / Double(max(1, Day.dayOfMonth(state.today)))
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(Money.short(perDay))
                                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text("per day vs ~\(Money.short(forecast.averageDailySpend)) typical")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        }
                    }

                    // Future
                    card {
                        HStack {
                            Label("Future balance", systemImage: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.0)
                                .foregroundStyle(accent)
                            Spacer()
                            Text("\(forecast.horizonDays) DAYS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        ForecastChart(forecast: forecast, accent: accent, height: 84)
                            .padding(.top, 6)
                        HStack(alignment: .firstTextBaseline) {
                            Text(Money.short(forecast.projected))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Spacer()
                            Text("IN \(forecast.horizonDays) DAYS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        Button { screen = .future } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles").font(.system(size: 10))
                                Text("See full future").font(.system(size: 12, weight: .semibold))
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.top, 10)

                    // Latest transactions, what already happened
                    HStack {
                        SectionLabel(text: "Latest transactions")
                        Spacer()
                        Button { showCalendar.toggle() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar").font(.system(size: 10))
                                Text(showCalendar ? "Hide calendar" : "Calendar")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundStyle(showCalendar ? accent : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)

                    VStack(spacing: 0) {
                        ForEach(state.recentTransactions(limit: 5)) { tx in
                            TransactionRow(transaction: tx, today: state.today)
                        }
                        if state.transactions.isEmpty {
                            Text("No transactions yet.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 4)

                    // Calendar, inline rather than a separate screen
                    if showCalendar {
                        ActivityCalendar(accent: accent)
                            .padding(.top, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Coming up, now a button through to the full list
                    Button { screen = .future } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.forward.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Coming up").font(.system(size: 12.5, weight: .semibold))
                                Text(comingUpSummary(forecast))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 11)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)

                } else if state.loading {
                    loadingBlock
                } else {
                    Text(state.errorMessage ?? "No data yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 24)
                }

                Divider().padding(.vertical, 10)
                HStack {
                    Text(state.usingProduction ? "Investec account" : "Investec sandbox")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let updated = state.lastUpdated {
                        Text("updated \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.never)
        .frame(height: 520)
        .animation(.easeInOut(duration: 0.2), value: showCalendar)
    }

    /// A small explanatory line under the headline number.
    private func balanceNote(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private func comingUpSummary(_ f: Forecast) -> String {
        guard let next = f.upcoming(limit: 1).first else { return "Nothing scheduled" }
        let when = Dates.relative(next.date, today: state.today).lowercased()
        return "\(next.label), \(Money.signed(next.amount)) \(when)"
    }

    private var loadingBlock: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Reading your account...").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}
