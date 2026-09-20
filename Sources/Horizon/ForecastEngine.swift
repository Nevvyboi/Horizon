import Foundation

// MARK: - Day arithmetic

enum Day {
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    static func start(_ d: Date) -> Date { cal.startOfDay(for: d) }
    static func add(_ d: Date, _ days: Int) -> Date {
        cal.date(byAdding: .day, value: days, to: d) ?? d
    }
    static func between(_ a: Date, _ b: Date) -> Int {
        cal.dateComponents([.day], from: start(a), to: start(b)).day ?? 0
    }
    static func sameMonth(_ a: Date, _ b: Date) -> Bool {
        cal.isDate(a, equalTo: b, toGranularity: .month)
    }
    static func dayOfMonth(_ d: Date) -> Int { cal.component(.day, from: d) }
}

// MARK: - Categorisation
//
// Keyword matching, nothing learned. Every label the interface shows can be
// traced back to a rule here.

enum Categoriser {
    private static let rules: [(Category, [String])] = [
        (.income, ["salary", "payroll", "wages", "income", "deposit", "eft credit", "payment received"]),
        (.housing, ["rent", "home loan", "bond", "landlord", "levy", "body corporate", "municipal rates"]),
        (.transport, ["uber", "bolt", "gautrain", "shell", "engen", "bp ", "sasol", "total", "caltex",
                      "petrol", "garage", "parking", "e-toll", "licence", "license"]),
        (.groceries, ["woolworths", "checkers", "pick n pay", "pnp", "spar", "shoprite", "food lover",
                      "grocer", "boxer", "usave"]),
        (.eatingOut, ["uber eats", "mr d", "nando", "kfc", "steers", "spur", "wimpy", "debonairs",
                      "cafe", "caffe", "restaurant", "mcdonald", "starbucks", "vida", "kauai"]),
        (.subscriptions, ["netflix", "spotify", "showmax", "youtube", "apple.com", "itunes", "disney",
                          "dstv", "prime", "icloud", "adobe", "openai", "microsoft", "google",
                          "dropbox", "canva", "subscription"]),
        (.insurance, ["outsurance", "discovery insure", "santam", "momentum", "old mutual", "hollard",
                      "miway", "king price", "insur"]),
        (.utilities, ["vodacom", "mtn", "telkom", "cell c", "rain", "afrihost", "webafrica", "city power",
                      "eskom", "water", "electric", "prepaid", "utilit"]),
        (.health, ["discovery health", "medical aid", "bonitas", "dischem", "clicks", "pharmac", "gym",
                   "virgin active", "planet fitness", "dentist", "doctor", "hospital"]),
        (.debt, ["vehicle finance", "credit card", "loan repayment", "wesbank", "personal loan", "installment"]),
        (.savings, ["transfer to savings", "tfsa", "unit trust", "easyequities", "retirement", "annuity",
                    "money market"]),
        (.shopping, ["takealot", "amazon", "superbalist", "zara", "cotton on", "mr price", "edgars",
                     "game ", "makro", "incredible", "builders", "apple store"]),
        (.cash, ["atm", "cash withdrawal", "withdrawal", "cash send"]),
    ]

    static func categorise(_ description: String, direction: Direction) -> Category {
        let s = description.lowercased()
        for (category, keys) in rules where keys.contains(where: { s.contains($0) }) {
            return category
        }
        return direction == .money_in ? .income : .other
    }
}

// MARK: - Recurring detection
//
// Regularity beats volume. A real debit order lands on nearly the same interval
// every month; noisy card spending at the same shop does not.

enum RecurringDetector {
    /// Strip store numbers and place names so repeats actually group together.
    static func key(for description: String) -> String {
        let upper = description.uppercased()
        let stripped = upper.unicodeScalars.map { scalar -> Character in
            CharacterSet.letters.contains(scalar) || scalar == " " ? Character(scalar) : " "
        }
        let noise: Set<String> = ["SANDTON", "JOBURG", "JHB", "CPT", "ZA", "SA", "PREMIUM", "TAP", "EXT"]
        return String(stripped)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !noise.contains($0) }
            .joined(separator: " ")
    }

    private static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let mid = s.count / 2
        return s.count % 2 == 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2
    }

    /// Returns recurring info keyed by transaction id.
    static func detect(_ transactions: [Transaction], today: Date) -> [String: RecurringInfo] {
        var groups: [String: [Transaction]] = [:]
        for tx in transactions {
            let k = key(for: tx.describedAs)
            guard !k.isEmpty else { continue }
            groups[k, default: []].append(tx)
        }

        var result: [String: RecurringInfo] = [:]
        for (_, list) in groups {
            guard list.count >= 3 else { continue }
            let dates = list.map(\.date).sorted()
            var gaps: [Double] = []
            for i in 1..<dates.count {
                gaps.append(Double(Day.between(dates[i - 1], dates[i])))
            }
            let cadence = Int(median(gaps).rounded())
            guard cadence >= 5, cadence <= 45 else { continue }

            let spread = gaps.map { abs($0 - Double(cadence)) }.reduce(0, +) / Double(gaps.count)
            let regularity = max(0, 1 - spread / (Double(cadence) * 0.5))
            guard regularity >= 0.6 else { continue }

            let volume = min(1, Double(list.count) / 3)
            let confidence = min(0.99, 0.7 * regularity + 0.3 * volume)
            guard confidence >= 0.75 else { continue }

            var next = Day.add(dates.last!, cadence)
            while Day.between(today, next) < 0 { next = Day.add(next, cadence) }

            let info = RecurringInfo(
                confidence: confidence,
                cadenceDays: cadence,
                nextDate: next,
                typicalAmount: median(list.map { abs($0.amount) }).rounded()
            )
            for tx in list { result[tx.id] = info }
        }
        return result
    }

    /// Attach recurring info onto each transaction.
    static func annotate(_ transactions: [Transaction], today: Date) -> [Transaction] {
        let info = detect(transactions, today: today)
        return transactions.map { tx in
            var copy = tx
            copy.recurring = info[tx.id]
            return copy
        }
    }
}

// MARK: - Forecast engine
//
// No black box. Start from the balance, lay the known recurring events onto a
// calendar, add estimated everyday spending, then walk day by day.

enum ForecastEngine {

    private struct Commitment {
        var key: String
        var label: String
        var category: Category
        var direction: Direction
        var cadenceDays: Int
        var nextDate: Date
        var typicalAmount: Double
        var confidence: Double
    }

    private static func commitments(from transactions: [Transaction]) -> [Commitment] {
        var seen: [String: Commitment] = [:]
        for tx in transactions {
            guard let r = tx.recurring else { continue }
            let k = RecurringDetector.key(for: tx.describedAs)
            if seen[k] != nil { continue }
            seen[k] = Commitment(
                key: k,
                label: tx.describedAs.capitalized,
                category: tx.category,
                direction: tx.direction,
                cadenceDays: r.cadenceDays,
                nextDate: r.nextDate,
                typicalAmount: r.typicalAmount,
                confidence: r.confidence
            )
        }
        return Array(seen.values)
    }

    /// Average daily outflow over the window, ignoring recurring commitments.
    private static func dailySpend(_ transactions: [Transaction], today: Date, window: Int = 60) -> Double {
        let cutoff = Day.add(today, -window)
        var total: Double = 0
        for tx in transactions where tx.amount < 0 && tx.recurring == nil {
            if tx.date >= cutoff && tx.date <= today { total += abs(tx.amount) }
        }
        return (total / Double(window)).rounded()
    }

    static func build(
        balance: Balance,
        transactions: [Transaction],
        today: Date,
        horizonDays: Int = 30,
        scenario: Scenario? = nil
    ) -> Forecast {
        let today = Day.start(today)
        let list = commitments(from: transactions)
        var avgDaily = dailySpend(transactions, today: today)

        // Expand commitments into dated events across the horizon.
        var events: [UpcomingEvent] = []
        let end = Day.add(today, horizonDays)
        for c in list {
            var date = c.nextDate
            var guardCount = 0
            while date <= end && guardCount < 8 {
                events.append(UpcomingEvent(
                    id: "\(c.key)-\(date.timeIntervalSince1970)",
                    date: date,
                    label: c.label,
                    amount: c.direction == .money_in ? c.typicalAmount : -c.typicalAmount,
                    category: c.category,
                    kind: .recurring,
                    confidence: c.confidence
                ))
                date = Day.add(date, c.cadenceDays)
                guardCount += 1
            }
        }

        // Apply the scenario to the event list before the walk.
        if let s = scenario {
            if let needle = s.cancelRecurring?.lowercased() {
                events.removeAll { $0.label.lowercased().contains(needle) }
            }
            if s.incomeShiftDays != 0 {
                events = events.map { e in
                    guard e.direction == .money_in else { return e }
                    var copy = e
                    copy.date = Day.add(e.date, s.incomeShiftDays)
                    return copy
                }
            }
            if s.spendMultiplier != 1 {
                avgDaily = (avgDaily * s.spendMultiplier).rounded()
            }
        }

        // Estimated everyday spending, one event per future day.
        for d in 1...max(1, horizonDays) {
            events.append(UpcomingEvent(
                id: "spend-\(d)",
                date: Day.add(today, d),
                label: "Typical spending",
                amount: -avgDaily,
                category: .other,
                kind: .estimatedSpend,
                confidence: 0.7
            ))
        }
        events.append(contentsOf: scenario?.extraEvents ?? [])

        // Walk day by day.
        var byDay: [Int: [UpcomingEvent]] = [:]
        for e in events {
            byDay[Day.between(today, e.date), default: []].append(e)
        }

        var points: [ForecastPoint] = [
            ForecastPoint(date: today, dayOffset: 0, balance: balance.available, events: [])
        ]
        var running = balance.available
        for d in 1...max(1, horizonDays) {
            let dayEvents = byDay[d] ?? []
            running += dayEvents.reduce(0) { $0 + $1.amount }
            points.append(ForecastPoint(
                date: Day.add(today, d),
                dayOffset: d,
                balance: running.rounded(),
                events: dayEvents
            ))
        }

        let lowestPoint = points.min { $0.balance < $1.balance } ?? points[0]
        let projected = points.last?.balance ?? balance.available

        let income = events.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let recurringOut = events.filter { $0.amount < 0 && $0.kind == .recurring }.reduce(0) { $0 + $1.amount }
        let spendOut = events.filter { $0.amount < 0 && $0.kind != .recurring }.reduce(0) { $0 + $1.amount }

        let monthlyCommitments = list.filter { $0.direction == .money_out }
            .reduce(0) { $0 + $1.typicalAmount }
        let threshold = monthlyCommitments > 0 ? monthlyCommitments : balance.available * 0.3
        let outlook: Outlook = lowestPoint.balance > threshold ? .comfortable
            : lowestPoint.balance > threshold * 0.25 ? .tight : .low

        var assumptions = [
            "\(list.count) recurring payments detected",
            "3 months of transaction history",
        ]
        if income > 0 { assumptions.append("Expected income included") }
        assumptions.append("Average daily spending of about \(Money.short(avgDaily))")

        return Forecast(
            startBalance: balance.available,
            horizonDays: horizonDays,
            points: points,
            lowest: (lowestPoint.date, lowestPoint.balance, lowestPoint.dayOffset),
            projected: projected,
            outlook: outlook,
            breakdown: ForecastBreakdown(
                startBalance: balance.available,
                expectedIncome: income,
                recurringPayments: recurringOut,
                typicalSpending: spendOut,
                projected: projected
            ),
            assumptions: assumptions,
            averageDailySpend: avgDaily
        )
    }

    /// The at-a-glance numbers behind the ring gauges.
    static func glance(_ forecast: Forecast, transactions: [Transaction], today: Date) -> GlanceStats {
        let nextIncome = forecast.upcoming(limit: 20).first { $0.direction == .money_in }
        let days = nextIncome.map { max(0, Day.between(today, $0.date)) }
        let cycle = 30.0
        let progress = days.map { min(1, max(0, (cycle - Double($0)) / cycle)) } ?? 0

        var spent: Double = 0
        for tx in transactions where tx.amount < 0 && Day.sameMonth(tx.date, today) {
            spent += abs(tx.amount)
        }
        let recurringMonthly = abs(forecast.breakdown.recurringPayments)
        let typicalMonthly = forecast.averageDailySpend * 30 + recurringMonthly
        let spentFraction = typicalMonthly > 0 ? min(1, spent / typicalMonthly) : 0
        let buffer = forecast.startBalance > 0
            ? min(1, max(0, forecast.lowest.balance / forecast.startBalance)) : 0

        return GlanceStats(
            daysToPayday: days,
            payCycleProgress: progress,
            spentThisMonth: spent,
            typicalMonthly: typicalMonthly,
            spentFraction: spentFraction,
            bufferFraction: buffer
        )
    }
}
