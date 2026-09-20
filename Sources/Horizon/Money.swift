import Foundation

/// Rand formatting. Tight, tabular, no cents unless they matter.
enum Money {
    private static let whole: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = " "
        f.usesGroupingSeparator = true
        return f
    }()

    private static let cents: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = " "
        f.usesGroupingSeparator = true
        return f
    }()

    /// R33 607
    static func short(_ amount: Double) -> String {
        "R" + (whole.string(from: NSNumber(value: amount.rounded())) ?? "0")
    }

    /// R199.00
    static func exact(_ amount: Double) -> String {
        "R" + (cents.string(from: NSNumber(value: amount)) ?? "0.00")
    }

    /// +R32 000 or -R8 500
    static func signed(_ amount: Double) -> String {
        (amount >= 0 ? "+" : "-") + short(abs(amount))
    }
}

enum Dates {
    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
    private static let longDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f
    }()

    /// TODAY, TOMORROW, or 25 SEP
    static func relative(_ date: Date, today: Date) -> String {
        switch Day.between(today, date) {
        case 0: return "TODAY"
        case 1: return "TOMORROW"
        default: return dayMonth.string(from: date).uppercased()
        }
    }

    static func long(_ date: Date) -> String { longDay.string(from: date) }
}
