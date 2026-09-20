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
        .animation(.easeInOut(duration: 0.22), value: screen)
        .animation(.easeInOut(duration: 0.25), value: state.connected)
    }
}

struct QuickView: View {
    @EnvironmentObject var state: AppState
    @Binding var screen: Screen
    @State private var monthView = true

    var body: some View {
        let accent = state.settings.accent.color

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    HStack(spacing: 6) {
                        ZebraMark(size: 15, color: accent)
                        Text("Horizon").font(.system(size: 12, weight: .semibold))
                    }
                    Spacer()
                    Button { Task { await state.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Button { screen = .settings } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 14)

                if let forecast = state.forecast, let glance = state.glance {

                    // Balance
                    SectionLabel(text: "Available balance")
                    Text(Money.short(forecast.startBalance))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
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

                    // Coming up
                    SectionLabel(text: "Coming up")
                        .padding(.top, 16)
                    VStack(spacing: 0) {
                        ForEach(forecast.upcoming(limit: 4)) { event in
                            EventRow(event: event, today: state.today, accent: accent)
                        }
                    }
                    .padding(.top, 4)

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
        .frame(height: 520)
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
