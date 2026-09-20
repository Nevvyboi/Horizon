import SwiftUI

/// Money movement across the month, at a glance.
///
/// Month mode draws a calendar with a dot on every day that has activity:
/// filled dots are transactions that already happened, hollow ones are
/// forecast. Day mode lists a single day in full.
struct ActivityView: View {
    @EnvironmentObject var state: AppState
    @Binding var screen: Screen

    enum Mode: String, CaseIterable { case month = "Month", day = "Day" }

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
        let accent = state.settings.accent.color

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(accent)

                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.bottom, 12)

                if mode == .month {
                    monthGrid(accent)
                    Divider().padding(.vertical, 12)
                    dayDetail(selected, accent: accent)
                } else {
                    dayStepper(accent)
                    dayDetail(selected, accent: accent)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.never)
        .frame(height: 520)
    }

    // MARK: - Header

    private func header(_ accent: Color) -> some View {
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
            Text("Activity").font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Data

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

    // MARK: - Month grid

    private func monthGrid(_ accent: Color) -> some View {
        let cal = Day.cal
        let activity = byDay
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        let firstOfMonth = cal.date(from: comps) ?? monthAnchor
        let dayCount = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let leading = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
        let symbols = cal.veryShortWeekdaySymbols
        let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text(monthTitle(firstOfMonth))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                // Index as the id: the weekday letters repeat (T/T, S/S) and
                // \.self would collapse the duplicates.
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                    Text(s.uppercased())
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 34) }
                ForEach(1...dayCount, id: \.self) { dayNumber in
                    let date = cal.date(byAdding: .day, value: dayNumber - 1, to: firstOfMonth) ?? firstOfMonth
                    dayCell(date, items: activity[Day.start(date)] ?? [], accent: accent)
                }
            }
        }
    }

    private func dayCell(_ date: Date, items: [Item], accent: Color) -> some View {
        let isToday = Day.between(state.today, date) == 0
        let isSelected = Day.between(selected, date) == 0
        let hasIn = items.contains { $0.amount > 0 }
        let hasOut = items.contains { $0.amount < 0 }
        let anyForecast = items.allSatisfy(\.forecast) && !items.isEmpty

        return Button {
            selected = Day.start(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(Day.dayOfMonth(date))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? accent : .primary)
                HStack(spacing: 2) {
                    if hasOut { dot(Palette.moneyOut, hollow: anyForecast) }
                    if hasIn { dot(Palette.moneyIn, hollow: anyForecast) }
                    if !hasIn && !hasOut { Color.clear.frame(width: 4, height: 4) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? accent.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isToday ? accent.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dot(_ color: Color, hollow: Bool) -> some View {
        Group {
            if hollow {
                Circle().stroke(color, lineWidth: 1).frame(width: 4.5, height: 4.5)
            } else {
                Circle().fill(color).frame(width: 4.5, height: 4.5)
            }
        }
    }

    // MARK: - Day

    private func dayStepper(_ accent: Color) -> some View {
        HStack {
            Button { selected = Day.add(selected, -1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            Text(Dates.long(selected))
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button { selected = Day.add(selected, 1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.bottom, 10)
    }

    private func dayDetail(_ date: Date, accent: Color) -> some View {
        let items = (byDay[Day.start(date)] ?? []).sorted { abs($0.amount) > abs($1.amount) }
        let total = items.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: Dates.relative(date, today: state.today))
                Spacer()
                if !items.isEmpty {
                    Text(Money.signed(total))
                        .font(.system(size: 11.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(total >= 0 ? Palette.moneyIn : Palette.moneyOut)
                }
            }
            .padding(.bottom, 6)

            if items.isEmpty {
                Text("Nothing moved on this day.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .strokeBorder(
                                item.amount >= 0 ? Palette.moneyIn : Palette.moneyOut,
                                lineWidth: item.forecast ? 1 : 3
                            )
                            .frame(width: 7, height: 7)
                        Text(item.label)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        if item.forecast {
                            Text("EXPECTED")
                                .font(.system(size: 7.5, weight: .semibold))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(accent.opacity(0.15), in: Capsule())
                                .foregroundStyle(accent)
                        }
                        Spacer(minLength: 6)
                        Text(Money.signed(item.amount))
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(item.amount >= 0 ? Palette.moneyIn : Palette.moneyOut)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Helpers

    private func shiftMonth(_ delta: Int) {
        monthAnchor = Day.cal.date(byAdding: .month, value: delta, to: monthAnchor) ?? monthAnchor
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
