import SwiftUI

/// Money movement, drilled down.
///
/// The top level is a cube per month showing what moved across it, signed,
/// because a month is a change and not a balance. Hovering one reports the
/// balance it ended on, reconstructed by winding the transaction feed back
/// off today's figure. Pressing one opens a cube per day, where each day
/// reads as used or gained, and pressing a day lists what moved.
///
/// Anything that has not happened yet is a forecast and is marked as one:
/// months carry a tilde, days are drawn hollow, and the wording says
/// expected rather than gained. Months the transaction feed does not reach
/// say so instead of reporting the oldest balance we happen to know.
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
                    monthReadout(hovered, facts(for: hovered))
                } else {
                    let net = dayNet(hovered)
                    let ahead = Day.between(state.today, hovered) > 0
                    HStack(spacing: 6) {
                        Text(Dates.relative(hovered, today: state.today))
                            .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        if net == 0 {
                            Text(ahead ? "nothing expected" : "nothing moved")
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                        } else {
                            Text(ahead ? "\(Money.signed(net)) expected" : signedPhrase(net))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(net >= 0 ? Palette.moneyIn : Palette.moneyOut)
                        }
                    }
                }
            } else {
                Text(openMonth == nil ? "Hover a month for the balance it ended on" : "Hover a day for what moved")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 26, alignment: .topLeading)
    }

    /// What the hover line says about a month.
    ///
    /// A month that has not finished can only be projected, and the number on
    /// its cube is part history and part forecast, so say which is which
    /// rather than presenting a guess as a closing balance.
    @ViewBuilder
    private func monthReadout(_ month: Date, _ f: MonthFacts) -> some View {
        // Two lines rather than one: at 340 points a month name, a balance
        // and a breakdown do not fit side by side, and the interesting half
        // is the half that gets truncated.
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(monthTitle(month))
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                if f.covered {
                    Text(closingPhrase(f))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(f.closing < 0 ? Palette.moneyOut : .primary)
                }
            }
            if !f.covered {
                Text("older than your transaction history")
                    .font(.system(size: 9.5)).foregroundStyle(.tertiary)
            } else if f.mixed {
                Text("\(signedPhrase(f.actual)) so far, \(Money.signed(f.projected)) still expected")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else if f.net != 0 {
                Text(signedPhrase(f.net))
                    .font(.system(size: 9.5))
                    .foregroundStyle(f.net >= 0 ? Palette.moneyIn : Palette.moneyOut)
            }
        }
    }

    /// How to describe where the balance stands for a month.
    private func closingPhrase(_ f: MonthFacts) -> String {
        guard f.ahead else { return "\(Money.short(f.closing)) left" }
        if let asOf = f.asOf {
            return "\(Money.short(f.closing)) projected by \(Dates.dayMonth(asOf))"
        }
        return "\(Money.short(f.closing)) projected"
    }

    private func signedPhrase(_ amount: Double) -> String {
        amount >= 0 ? "gained \(Money.short(amount))" : "used \(Money.short(abs(amount)))"
    }

    private func tooltip(_ month: Date, _ f: MonthFacts) -> String {
        guard f.covered else { return "\(monthTitle(month)): older than your transaction history" }
        let position = f.ahead
            ? (f.asOf.map { "on track for \(Money.short(f.closing)) by \(Dates.dayMonth($0))" }
               ?? "on track to end at \(Money.short(f.closing))")
            : "ended at \(Money.short(f.closing))"
        return "\(monthTitle(month)): \(position), \(signedPhrase(f.net))"
    }

    // MARK: - Month cubes

    private var monthCubes: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(months, id: \.self) { month in
                MonthCube(
                    title: shortMonth(month).uppercased(),
                    facts: facts(for: month),
                    tooltip: tooltip(month, facts(for: month)),
                    isNow: Day.cal.isDate(month, equalTo: state.today, toGranularity: .month),
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
        let facts: MonthFacts
        let tooltip: String
        let isNow: Bool
        let isHovered: Bool
        let accent: Color
        let open: () -> Void
        let hover: (Bool) -> Void

        private var flat: Bool { facts.net == 0 }
        private var tint: Color { facts.net > 0 ? Palette.moneyIn : Palette.moneyOut }

        var body: some View {
            let dead = !facts.covered
            let amountColor: Color = dead || flat ? .secondary : tint
            let fill: Color = dead || flat
                ? Color.primary.opacity(isHovered ? 0.1 : 0.04)
                : tint.opacity(isHovered ? 0.34 : 0.16)
            // A signed figure, because this is movement across the month and
            // not the balance. Months still partly ahead of us carry a tilde
            // so a projection never passes for a fact.
            let amount = dead ? "no data"
                : flat ? "quiet"
                : (facts.mixed ? "~" : "") + Money.signed(facts.net)

            Button(action: open) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 10.5, weight: isNow ? .bold : .medium))
                        .foregroundStyle(isNow ? accent : Color.primary)
                    Text(amount)
                        .font(.system(size: 9.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(amountColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 8).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isNow ? accent.opacity(0.6) : Color.clear, lineWidth: 1)
                )
                .opacity(dead ? 0.5 : (facts.ahead && !isNow ? 0.7 : 1))
            }
            .buttonStyle(.plain)
            .onHover(perform: hover)
            .help(tooltip)
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
                    ahead: Day.between(state.today, date) > 0,
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
        /// A day that has not happened yet, so anything on it is expected
        /// rather than done.
        let ahead: Bool
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
            let tip = flat
                ? (ahead ? "Nothing expected" : "Nothing moved")
                : ahead
                    ? (net > 0 ? "Expecting \(Money.short(net)) in" : "Expecting \(Money.short(abs(net))) out")
                    : (net > 0 ? "Gained \(Money.short(net))" : "Used \(Money.short(abs(net)))")

            Button(action: open) {
                VStack(spacing: 1) {
                    Text("\(number)")
                        .font(.system(size: 9.5, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? accent : Color.primary)
                    // Hollow means expected, solid means it happened.
                    Group {
                        if flat {
                            Circle().fill(Color.clear)
                        } else if ahead {
                            Circle().strokeBorder(tint, lineWidth: 1)
                        } else {
                            Circle().fill(tint)
                        }
                    }
                    .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 6).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(border, lineWidth: 1))
                .opacity(ahead ? 0.72 : 1)
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

    /// The months worth showing: everything the transaction feed reaches back
    /// to, through to the month the forecast runs into, capped at a year.
    ///
    /// Investec only hands back a window of transactions, so going back
    /// further than the feed would fill the grid with months the app knows
    /// nothing about.
    private var months: [Date] {
        let cal = Day.cal
        let end = cal.date(from: cal.dateComponents([.year, .month],
                                                    from: Day.add(state.today, 30))) ?? state.today
        var count = 12
        if let first = feedStart,
           let startMonth = cal.date(from: cal.dateComponents([.year, .month], from: first)),
           let span = cal.dateComponents([.month], from: startMonth, to: end).month {
            count = min(12, max(1, span + 1))
        }
        return (0..<count).reversed().compactMap { cal.date(byAdding: .month, value: -$0, to: end) }
    }

    /// The oldest transaction the feed gave us, which is as far back as any
    /// reconstruction can honestly go.
    private var feedStart: Date? {
        state.transactions.map(\.date).min()
    }

    /// Everything the month grid needs to know about one month.
    struct MonthFacts {
        /// Net of postings that have actually happened.
        var actual: Double = 0
        /// Net of events the forecast expects but that have not happened.
        var projected: Double = 0
        /// Where the balance stands, or is expected to stand, at month end.
        var closing: Double = 0
        /// Whether the feed reaches this month at all.
        var covered: Bool = true
        /// Whether any part of this month is still ahead of us.
        var ahead: Bool = false
        /// Set when the month runs past the end of the forecast, so the
        /// closing figure is only as far as the projection reaches.
        var asOf: Date?

        var net: Double { actual + projected }
        var mixed: Bool { ahead && projected != 0 }
    }

    private func facts(for month: Date) -> MonthFacts {
        let cal = Day.cal
        var out = MonthFacts()
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return out }

        out.ahead = end >= state.today
        // A month that ended before the feed begins cannot be described. Say
        // so rather than reporting a balance that is really just the oldest
        // one we happen to know.
        out.covered = out.ahead || (feedStart.map { end >= Day.start($0) } ?? false)

        for tx in state.transactions where cal.isDate(tx.date, equalTo: month, toGranularity: .month) {
            out.actual += tx.amount
        }
        if let forecast = state.forecast {
            for e in forecast.points.flatMap(\.events)
            where e.kind != .estimatedSpend
                && cal.isDate(e.date, equalTo: month, toGranularity: .month)
                && e.date > state.today {
                out.projected += e.amount
            }
        }

        if out.ahead {
            // Read the projection off the forecast curve, clamped to where it
            // actually reaches: beyond the horizon there is nothing to say.
            let cap = state.forecast?.points.last?.date ?? state.today
            if end > cap { out.asOf = cap }
            out.closing = forecast(upTo: min(end, cap)) ?? state.balance?.settled ?? 0
        } else {
            let after = state.transactions
                .filter { $0.date > end }
                .reduce(0) { $0 + $1.amount }
            out.closing = (state.balance?.settled ?? 0) - after
        }
        return out
    }

    private func forecast(upTo date: Date) -> Double? {
        state.forecast?.points.last { $0.date <= date }?.balance
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
