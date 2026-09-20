import SwiftUI

struct FutureView: View {
    @EnvironmentObject var state: AppState
    @Binding var screen: Screen

    @State private var scenario: Scenario?
    @State private var showExplain = false

    private var scenarios: [Scenario] {
        let today = state.today
        return [
            Scenario(id: "spend", label: "Spend R3 000 today", extraEvents: [
                UpcomingEvent(id: "s1", date: today, label: "One off spend", amount: -3000,
                              category: .other, kind: .known, confidence: 1)
            ]),
            Scenario(id: "late", label: "Salary 3 days late", incomeShiftDays: 3),
            Scenario(id: "save", label: "Save R2 000", extraEvents: [
                UpcomingEvent(id: "s2", date: today, label: "Move to savings", amount: -2000,
                              category: .savings, kind: .known, confidence: 1)
            ]),
            Scenario(id: "cutback", label: "Cut spending 30%", spendMultiplier: 0.7),
        ]
    }

    var body: some View {
        let accent = state.settings.accent.color
        let base = state.forecast
        let current = state.forecast(with: scenario) ?? base

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
                    Button { showExplain.toggle() } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(showExplain ? accent : .secondary)
                }
                .padding(.bottom, 12)

                if let base, let current {
                    SectionLabel(text: scenario == nil ? "Future balance" : "Scenario forecast")

                    // The ladder
                    VStack(spacing: 2) {
                        ForEach(ladderMarks(current), id: \.0) { mark in
                            HStack {
                                Text(mark.0)
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(0.8)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text(Money.short(mark.1))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.top, 6)

                    ForecastChart(
                        forecast: current,
                        accent: accent,
                        height: 110,
                        ghost: scenario == nil ? nil : base
                    )
                    .padding(.top, 10)

                    // Outlook
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(text: "Financial outlook")
                        HStack(spacing: 6) {
                            Circle().fill(Palette.outlook(current.outlook)).frame(width: 6, height: 6)
                            Text(current.outlook.label).font(.system(size: 14, weight: .medium))
                        }
                        Text("Projected minimum of \(Money.short(current.lowest.balance)) on \(Dates.long(current.lowest.date)), before your next expected income.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                    .padding(.top, 12)

                    if showExplain {
                        explain(current, accent: accent)
                    }

                    // Scenarios
                    SectionLabel(text: "What if?").padding(.top, 16)
                    FlowChips(items: scenarios, selected: scenario?.id, accent: accent) { picked in
                        scenario = (scenario?.id == picked.id) ? nil : picked
                    }
                    .padding(.top, 6)

                    if let scenario, let current = state.forecast(with: scenario) {
                        compare(base: base, scenario: current, accent: accent)
                    }

                    // Timeline
                    SectionLabel(text: "Timeline").padding(.top, 16)
                    VStack(spacing: 0) {
                        ForEach(current.upcoming(limit: 7)) { event in
                            EventRow(event: event, today: state.today, accent: accent)
                        }
                    }
                    .padding(.top, 4)

                    Text("Projected from recent activity. Estimates, not guarantees.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 12)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.never)
        .frame(height: 520)
    }

    private func ladderMarks(_ f: Forecast) -> [(String, Double)] {
        [0, 7, 14, f.horizonDays].map { d in
            let p = f.points.first { $0.dayOffset == d } ?? f.points[f.points.count - 1]
            return (d == 0 ? "TODAY" : "\(d) DAYS", p.balance)
        }
    }

    private func compare(base: Forecast, scenario: Forecast, accent: Color) -> some View {
        let delta = scenario.lowest.balance - base.lowest.balance
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Projected minimum balance")
            HStack(spacing: 10) {
                block("Current plan", Money.short(base.lowest.balance), tint: .clear)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                block("Scenario", Money.short(scenario.lowest.balance), tint: accent.opacity(0.15))
            }
            Text("\(delta >= 0 ? "Lifts" : "Lowers") your projected minimum by \(Money.short(abs(delta))).")
                .font(.system(size: 11))
                .foregroundStyle(delta >= 0 ? Palette.moneyIn : Palette.moneyOut)
        }
        .padding(.top, 10)
    }

    private func block(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(tint == .clear ? Color.primary.opacity(0.05) : tint,
                    in: RoundedRectangle(cornerRadius: 9))
    }

    private func explain(_ f: Forecast, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Why \(Money.short(f.projected))?")
                .padding(.bottom, 6)
            row("Starting balance", Money.short(f.breakdown.startBalance), nil)
            row("Expected income", Money.signed(f.breakdown.expectedIncome), Palette.moneyIn)
            row("Recurring payments", Money.signed(f.breakdown.recurringPayments), Palette.moneyOut)
            row("Typical spending", Money.signed(f.breakdown.typicalSpending), Palette.moneyOut)
            Divider().padding(.vertical, 4)
            row("Projected", Money.short(f.breakdown.projected), nil, bold: true)

            SectionLabel(text: "Based on").padding(.top, 10).padding(.bottom, 4)
            ForEach(f.assumptions, id: \.self) { a in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Palette.moneyIn)
                    Text(a).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 1)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
        .padding(.top, 10)
    }

    private func row(_ label: String, _ value: String, _ tint: Color?, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5, weight: bold ? .semibold : .regular))
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: bold ? 14 : 11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint ?? .primary)
        }
        .padding(.vertical, 3)
    }
}

/// Wrapping row of selectable chips.
struct FlowChips: View {
    let items: [Scenario]
    let selected: String?
    let accent: Color
    let onPick: (Scenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { i in
                HStack(spacing: 6) {
                    chip(items[i])
                    if i + 1 < items.count { chip(items[i + 1]) }
                }
            }
        }
    }

    private func chip(_ s: Scenario) -> some View {
        Button { onPick(s) } label: {
            Text(s.label)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    selected == s.id ? accent.opacity(0.2) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
                .foregroundStyle(selected == s.id ? accent : .secondary)
        }
        .buttonStyle(.plain)
    }
}
