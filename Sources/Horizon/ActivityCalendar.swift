import SwiftUI

/// Money movement, drilled down.
///
/// The top level is a cube per month. Hovering one reports what was left at
/// the end of that month, which is reconstructed by walking the transaction
/// feed back from today's balance. Pressing one opens a cube per day, where
/// each day reads as used or gained, and pressing a day lists what moved.
struct ActivityCalendar: View {
    @EnvironmentObject var state: AppState
    var accent: Color

    @State private var openMonth: Date?
    @State private var selectedDay: Date?
    @State private var hovered: Date?

    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let forecast: Bool
        var pending: Bool = false

        /// What to show next to the amount, if anything.
        var tag: String? {
            if forecast { return "EXPECTED" }
            if pending { return "PENDING" }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            readout
                .padding(.bottom, 9)

            if let month = openMonth {
                dayCubes(for: month)
                if let day = selectedDay {
                    Divider().padding(.vertical, 9)
                    dayDetail(day)
                }
            } else {
                monthCubes
            }
        }
        .padding(11)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .animation(.easeInOut(duration: 0.18), value: openMonth)
    }

    // MARK: - Header and hover readout

    private var header: some View {
        HStack {
            if openMonth != nil {
                Button {
                    openMonth = nil
                    selectedDay = nil
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 9, weight: .semibold))
                        Text("Months").font(.system(size: 10.5))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                SectionLabel(text: "Months")
            }
            Spacer()
            if let month = openMonth {
                Text(monthTitle(month)).font(.system(size: 10.5, weight: .semibold))
            }
        }
        .padding(.bottom, 4)
    }

    /// One line that answers whatever the pointer is over.
    private var readout: some View {
        Group {
            if let hovered {
                if openMonth == nil {
                    let left = closingBalance(endOf: hovered)
                    let net = monthNet(hovered)
                    HStack(spacing: 6) {
                        Text("\(monthTitle(hovered)):")
                            .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        Text("\(Money.short(left)) left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(left < 0 ? Palette.moneyOut : .primary)
                        Text(net >= 0 ? "gained \(Money.short(net))" : "used \(Money.short(abs(net)))")
                            .font(.system(size: 10))
                            .foregroundStyle(net >= 0 ? Palette.moneyIn : Palette.moneyOut)
                    }
                } else {
                    let net = dayNet(hovered)
                    HStack(spacing: 6) {
                        Text(Dates.relative(hovered, today: state.today))
                            .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        if net == 0 {
                            Text("nothing moved").font(.system(size: 10)).foregroundStyle(.tertiary)
                        } else {
                            Text(net >= 0 ? "gained \(Money.short(net))" : "used \(Money.short(abs(net)))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(net >= 0 ? Palette.moneyIn : Palette.moneyOut)
                        }
                    }
                }
            } else {
                Text(openMonth == nil ? "Hover a month for what was left" : "Hover a day for what moved")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 14, alignment: .leading)
    }

    // MARK: - Month cubes

    private var monthCubes: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(months, id: \.self) { month in
                MonthCube(
                    title: shortMonth(month).uppercased(),
                    net: monthNet(month),
                    left: closingBalance(endOf: month),
                    tooltipTitle: monthTitle(month),
                    isNow: Day.cal.isDate(month, equalTo: state.today, toGranularity: .month),
                    isFuture: month > state.today,
                    isHovered: hovered == month,
                    accent: accent,
                    open: {
                        openMonth = month
                        selectedDay = nil
                    },
                    hover: { inside in
                        hovered = inside ? month : (hovered == month ? nil : hovered)
                    }
                )
            }
        }
    }

    /// One month. Pulled out of the grid because the compiler cannot type
    /// check this many conditional modifiers inside a ForEach body.
    private struct MonthCube: View {
        let title: String
        let net: Double
        let left: Double
        let tooltipTitle: String
        let isNow: Bool
        let isFuture: Bool
        let isHovered: Bool
        let accent: Color
        let open: () -> Void
        let hover: (Bool) -> Void

        private var flat: Bool { net == 0 }
        private var tint: Color { net > 0 ? Palette.moneyIn : Palette.moneyOut }

        var body: some View {
            let amountColor: Color = flat ? .secondary : tint
            let fill: Color = flat
                ? Color.primary.opacity(isHovered ? 0.1 : 0.04)
                : tint.opacity(isHovered ? 0.34 : 0.16)

            Button(action: open) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 10.5, weight: isNow ? .bold : .medium))
                        .foregroundStyle(isNow ? accent : Color.primary)
                    Text(flat ? "quiet" : Money.short(abs(net)))
                        .font(.system(size: 9.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(amountColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 8).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isNow ? accent.opacity(0.6) : Color.clear, lineWidth: 1)
                )
                .opacity(isFuture ? 0.65 : 1)
            }
            .buttonStyle(.plain)
            .onHover(perform: hover)
            .help("\(tooltipTitle): \(Money.short(left)) left")
        }
    }

    // MARK: - Day cubes

    private func dayCubes(for month: Date) -> some View {
        let cal = Day.cal
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(1...count, id: \.self) { n in
                let date = Day.start(cal.date(byAdding: .day, value: n - 1, to: first) ?? first)
                DayCube(
                    number: n,
                    net: dayNet(date),
                    isToday: Day.between(state.today, date) == 0,
                    isSelected: selectedDay.map { Day.between($0, date) == 0 } ?? false,
                    isHovered: hovered == date,
                    accent: accent,
                    open: { selectedDay = date },
                    hover: { inside in
                        hovered = inside ? date : (hovered == date ? nil : hovered)
                    }
                )
            }
        }
    }

    /// One day, reading as used or gained at a glance.
    private struct DayCube: View {
        let number: Int
        let net: Double
        let isToday: Bool
        let isSelected: Bool
        let isHovered: Bool
        let accent: Color
        let open: () -> Void
        let hover: (Bool) -> Void

        private var flat: Bool { net == 0 }
        private var tint: Color { net > 0 ? Palette.moneyIn : Palette.moneyOut }

        var body: some View {
            let lit = isHovered || isSelected
            let fill: Color = flat
                ? Color.primary.opacity(isHovered ? 0.08 : 0.03)
                : tint.opacity(lit ? 0.34 : 0.15)
            let border: Color = isSelected ? accent : (isToday ? accent.opacity(0.5) : .clear)
            let tip = flat ? "Nothing moved"
                : (net > 0 ? "Gained \(Money.short(net))" : "Used \(Money.short(abs(net)))")

            Button(action: open) {
                VStack(spacing: 1) {
                    Text("\(number)")
                        .font(.system(size: 9.5, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? accent : Color.primary)
                    Circle()
                        .fill(flat ? Color.clear : tint)
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 6).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .onHover(perform: hover)
            .help(tip)
        }
    }

    private func dayDetail(_ date: Date) -> some View {
        let items = self.items(on: date).sorted { abs($0.amount) > abs($1.amount) }
        let net = items.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: Dates.relative(date, today: state.today))
                Spacer()
                if !items.isEmpty {
                    Text(net >= 0 ? "gained \(Money.short(net))" : "used \(Money.short(abs(net)))")
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(net >= 0 ? Palette.moneyIn : Palette.moneyOut)
                }
            }
            .padding(.bottom, 5)

            if items.isEmpty {
                Text("Nothing moved on this day.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary).padding(.vertical, 4)
            } else {
                ForEach(items.prefix(8)) { item in
                    HStack(spacing: 7) {
                        Circle()
                            .strokeBorder(item.amount >= 0 ? Palette.moneyIn : Palette.moneyOut,
                                          lineWidth: item.forecast ? 1 : 3)
                            .frame(width: 6, height: 6)
                        Text(item.label).font(.system(size: 11)).lineLimit(1)
                        if let tag = item.tag {
                            Text(tag)
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

    // MARK: - Numbers

    /// Twelve months ending with the month the forecast runs into.
    private var months: [Date] {
        let cal = Day.cal
        let end = cal.date(from: cal.dateComponents([.year, .month],
                                                    from: Day.add(state.today, 30))) ?? state.today
        return (0..<12).reversed().compactMap { cal.date(byAdding: .month, value: -$0, to: end) }
    }

    private func items(on date: Date) -> [Item] {
        var out: [Item] = []
        for tx in state.transactions where Day.between(tx.date, date) == 0 {
            out.append(Item(label: tx.describedAs.capitalized, amount: tx.amount,
                            forecast: false, pending: tx.isPending))
        }
        if let forecast = state.forecast {
            for e in forecast.points.flatMap(\.events)
            where e.kind != .estimatedSpend && Day.between(e.date, date) == 0 {
                out.append(Item(label: e.label, amount: e.amount, forecast: true))
            }
        }
        return out
    }

    private func dayNet(_ date: Date) -> Double {
        items(on: date).reduce(0) { $0 + $1.amount }
    }

    private func monthNet(_ month: Date) -> Double {
        var total: Double = 0
        for tx in state.transactions where Day.cal.isDate(tx.date, equalTo: month, toGranularity: .month) {
            total += tx.amount
        }
        if let forecast = state.forecast {
            for e in forecast.points.flatMap(\.events)
            where e.kind != .estimatedSpend
                && Day.cal.isDate(e.date, equalTo: month, toGranularity: .month)
                && e.date > state.today {
                total += e.amount
            }
        }
        return total
    }

    /// What was left at the end of that month.
    ///
    /// Today's balance already includes everything up to now, so winding the
    /// later transactions back off it gives the closing position. For months
    /// still ahead of us, the forecast curve already has the answer.
    private func closingBalance(endOf month: Date) -> Double {
        let cal = Day.cal
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return state.balance?.settled ?? 0 }

        if end >= state.today {
            if let forecast = state.forecast {
                let upTo = forecast.points.filter { $0.date <= end }
                if let last = upTo.last { return last.balance }
            }
            return state.balance?.settled ?? 0
        }
        let after = state.transactions
            .filter { $0.date > end }
            .reduce(0) { $0 + $1.amount }
        return (state.balance?.settled ?? 0) - after
    }

    private func tint(_ net: Double) -> Color {
        net > 0 ? Palette.moneyIn : Palette.moneyOut
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: date)
    }
    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: date)
    }
}
