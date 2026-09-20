import SwiftUI

/// Money movement across the month, as a calendar with a dot on every day that
/// has activity. Embedded under the balance rather than living on its own
/// screen, so it opens in place.
///
/// Filled dots already happened, hollow dots are forecast. Red is money out,
/// green is money in.
struct ActivityCalendar: View {
    @EnvironmentObject var state: AppState
    var accent: Color

    private enum Mode: String, CaseIterable { case month = "Month", day = "Day" }
    @State private var mode: Mode = .month
    @State private var selected: Date = Day.start(Date())
    @State private var monthAnchor: Date = Day.start(Date())

    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let forecast: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .padding(.bottom, 10)

            if mode == .month {
                monthGrid
                Divider().padding(.vertical, 10)
            } else {
                dayStepper
            }
            dayDetail(selected)
        }
        .padding(11)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    /// Everything that moves money, keyed by day.
    private var byDay: [Date: [Item]] {
        var map: [Date: [Item]] = [:]
        for tx in state.transactions {
            map[Day.start(tx.date), default: []].append(
                Item(label: tx.describedAs.capitalized, amount: tx.amount, forecast: false)
            )
        }
        if let forecast = state.forecast {
            for event in forecast.points.flatMap(\.events) where event.kind != .estimatedSpend {
                map[Day.start(event.date), default: []].append(
                    Item(label: event.label, amount: event.amount, forecast: true)
                )
            }
        }
        return map
    }

    private var monthGrid: some View {
        let cal = Day.cal
        let activity = byDay
        let first = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let sym = cal.veryShortWeekdaySymbols
        let ordered = Array(sym[(cal.firstWeekday - 1)...] + sym[..<(cal.firstWeekday - 1)])
        let cols = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text(monthTitle(first)).font(.system(size: 11.5, weight: .semibold))
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: cols, spacing: 1) {
                // Index as the id: the weekday letters repeat, and \.self
                // would collapse the duplicates.
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                    Text(s.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 29) }
                ForEach(1...days, id: \.self) { n in
                    let date = cal.date(byAdding: .day, value: n - 1, to: first) ?? first
                    dayCell(date, items: activity[Day.start(date)] ?? [])
                }
            }
        }
    }

    private func dayCell(_ date: Date, items: [Item]) -> some View {
        let isToday = Day.between(state.today, date) == 0
        let isSelected = Day.between(selected, date) == 0
        let hasIn = items.contains { $0.amount > 0 }
        let hasOut = items.contains { $0.amount < 0 }
        let allForecast = !items.isEmpty && items.allSatisfy(\.forecast)

        return Button { selected = Day.start(date) } label: {
            VStack(spacing: 1) {
                Text("\(Day.dayOfMonth(date))")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? accent : .primary)
                HStack(spacing: 2) {
                    if hasOut { dot(Palette.moneyOut, hollow: allForecast) }
                    if hasIn { dot(Palette.moneyIn, hollow: allForecast) }
                    if !hasIn && !hasOut { Color.clear.frame(width: 4, height: 4) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? accent.opacity(0.18) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isToday ? accent.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func dot(_ color: Color, hollow: Bool) -> some View {
        Group {
            if hollow {
                Circle().stroke(color, lineWidth: 1).frame(width: 4, height: 4)
            } else {
                Circle().fill(color).frame(width: 4, height: 4)
            }
        }
    }

    private var dayStepper: some View {
        HStack {
            Button { selected = Day.add(selected, -1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            Text(Dates.long(selected)).font(.system(size: 11.5, weight: .semibold))
            Spacer()
            Button { selected = Day.add(selected, 1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private func dayDetail(_ date: Date) -> some View {
        let items = (byDay[Day.start(date)] ?? []).sorted { abs($0.amount) > abs($1.amount) }
        let total = items.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: Dates.relative(date, today: state.today))
                Spacer()
                if !items.isEmpty {
                    Text(Money.signed(total))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(total >= 0 ? Palette.moneyIn : Palette.moneyOut)
                }
            }
            .padding(.bottom, 5)

            if items.isEmpty {
                Text("Nothing moved on this day.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 5)
            } else {
                ForEach(items.prefix(6)) { item in
                    HStack(spacing: 7) {
                        Circle()
                            .strokeBorder(item.amount >= 0 ? Palette.moneyIn : Palette.moneyOut,
                                          lineWidth: item.forecast ? 1 : 3)
                            .frame(width: 6, height: 6)
                        Text(item.label).font(.system(size: 11)).lineLimit(1)
                        if item.forecast {
                            Text("EXPECTED")
                                .font(.system(size: 7, weight: .semibold))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(accent.opacity(0.15), in: Capsule())
                                .foregroundStyle(accent)
                        }
                        Spacer(minLength: 4)
                        Text(Money.signed(item.amount))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(item.amount >= 0 ? Palette.moneyIn : Palette.moneyOut)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        monthAnchor = Day.cal.date(byAdding: .month, value: delta, to: monthAnchor) ?? monthAnchor
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
