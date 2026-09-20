import Foundation

// MARK: - Core shapes
//
// These sit close to what the Investec API returns so the live client and any
// sample data can be swapped without the rest of the app noticing.

enum Direction: String, Codable {
    case money_in
    case money_out
}

enum Category: String, Codable, CaseIterable {
    case income, housing, transport, groceries, eatingOut, subscriptions
    case insurance, utilities, health, debt, savings, shopping, cash, other

    var label: String {
        switch self {
        case .eatingOut: return "Eating out"
        default: return rawValue.capitalized
        }
    }

    /// SF Symbol used in lists and detail rows.
    var symbol: String {
        switch self {
        case .income: return "banknote"
        case .housing: return "house"
        case .transport: return "car"
        case .groceries: return "cart"
        case .eatingOut: return "fork.knife"
        case .subscriptions: return "play.rectangle"
        case .insurance: return "shield"
        case .utilities: return "bolt"
        case .health: return "heart"
        case .debt: return "creditcard"
        case .savings: return "arrow.down.circle"
        case .shopping: return "bag"
        case .cash: return "dollarsign.circle"
        case .other: return "circle"
        }
    }
}

struct RecurringInfo: Equatable {
    var confidence: Double      // 0...1
    var cadenceDays: Int
    var nextDate: Date
    var typicalAmount: Double
}

struct Transaction: Identifiable, Equatable {
    let id: String
    var date: Date
    var describedAs: String
    /// Signed rands. Positive is money in, negative is money out.
    var amount: Double
    var category: Category
    var isPending: Bool
    var recurring: RecurringInfo?

    var direction: Direction { amount >= 0 ? .money_in : .money_out }
}

struct Account: Identifiable, Equatable {
    let id: String
    var name: String
    var number: String
    var currency: String
}

struct Balance: Equatable {
    /// What you actually have. Negative when you are into a credit facility.
    var current: Double
    /// What you can still spend, which on a credit account includes borrowed
    /// headroom rather than your own money.
    var available: Double
    var currency: String

    /// Money already spent that the bank has not posted yet, signed the same
    /// way as a transaction so a card swipe waiting to settle is negative.
    ///
    /// Card purchases sit as an authorisation for a few days before the
    /// merchant claims them, and some merchants only settle in a weekly
    /// batch. The bank holds the money the whole time, so it is gone in every
    /// sense except the posted balance.
    var pending: Double = 0

    /// What is really yours once everything in flight lands.
    var settled: Double { current + pending }

    /// The size of the credit facility.
    ///
    /// Inferred from the gap between what may be spent and what is held. The
    /// available figure is already net of the holds, so the pending amount has
    /// to be added back or the facility reads short by whatever is in flight.
    var facility: Double { max(0, available - current - pending) }
    var usingCredit: Bool { settled < 0 }
    /// The real bottom: spending past this exceeds the facility.
    var floor: Double { -facility }
    var hasPending: Bool { abs(pending) >= 0.01 }
}

enum EventKind: Equatable {
    case recurring
    case known
    case estimatedSpend
}

struct UpcomingEvent: Identifiable, Equatable {
    let id: String
    var date: Date
    var label: String
    var amount: Double          // signed
    var category: Category
    var kind: EventKind
    var confidence: Double

    var direction: Direction { amount >= 0 ? .money_in : .money_out }
}

struct ForecastPoint: Identifiable, Equatable {
    var id: Int { dayOffset }
    var date: Date
    var dayOffset: Int
    var balance: Double
    var events: [UpcomingEvent]
}

enum Outlook: String {
    case comfortable, tight, low

    var label: String {
        switch self {
        case .comfortable: return "Comfortable"
        case .tight: return "Getting tight"
        case .low: return "Low buffer"
        }
    }
}

struct ForecastBreakdown: Equatable {
    var startBalance: Double
    var expectedIncome: Double
    var recurringPayments: Double   // negative
    var typicalSpending: Double     // negative
    var projected: Double
}

struct Forecast: Equatable {
    var startBalance: Double
    var horizonDays: Int
    var points: [ForecastPoint]
    var lowest: (date: Date, balance: Double, dayOffset: Int)
    var projected: Double
    var outlook: Outlook
    var breakdown: ForecastBreakdown
    var assumptions: [String]
    var averageDailySpend: Double

    static func == (a: Forecast, b: Forecast) -> Bool {
        a.startBalance == b.startBalance && a.points == b.points && a.projected == b.projected
    }

    /// Named events coming up, leaving out the estimated daily spend noise.
    func upcoming(limit: Int = 8) -> [UpcomingEvent] {
        points.flatMap { $0.events }
            .filter { $0.kind != .estimatedSpend }
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }
}

/// A hypothetical layered on top of the base forecast.
struct Scenario: Identifiable, Equatable {
    let id: String
    var label: String
    var extraEvents: [UpcomingEvent] = []
    var incomeShiftDays: Int = 0
    var spendMultiplier: Double = 1
    var cancelRecurring: String? = nil
}

struct GlanceStats {
    var daysToPayday: Int?
    var payCycleProgress: Double
    var spentThisMonth: Double
    var typicalMonthly: Double
    var spentFraction: Double
    var bufferFraction: Double
}
