import SwiftUI

private func hex(_ value: UInt32) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

/// Accent themes, drawn from the Floati palette. Money in and money out keep
/// their own colours, because green and red carry meaning rather than brand.
struct Accent: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color

    static let all: [Accent] = [
        Accent(id: "indigo", name: "Indigo", color: hex(0x5B5BF6)),
        Accent(id: "violet", name: "Violet", color: hex(0x7C3AED)),
        Accent(id: "teal",   name: "Teal",   color: hex(0x0891B2)),
        Accent(id: "green",  name: "Green",  color: hex(0x2D9D78)),
        Accent(id: "amber",  name: "Amber",  color: hex(0xD97706)),
        Accent(id: "rose",   name: "Rose",   color: hex(0xE11D48)),
    ]

    static func named(_ id: String) -> Accent {
        all.first { $0.id == id } ?? all[0]
    }
}

enum Palette {
    /// Floati greens and reds.
    static let moneyIn = hex(0x2D9D78)
    static let moneyOut = hex(0xE11D48)
    static let warn = hex(0xD97706)
    /// Floati paper and ink, for surfaces that need a warm base.
    static let paper = hex(0xF0EDE6)
    static let inkDeep = hex(0x1A1614)

    static func outlook(_ o: Outlook) -> Color {
        switch o {
        case .comfortable: return moneyIn
        case .tight: return warn
        case .low: return moneyOut
        }
    }
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    @Published var accentId: String {
        didSet { UserDefaults.standard.set(accentId, forKey: "accentId") }
    }
    @Published var refreshMinutes: Int {
        didSet { UserDefaults.standard.set(refreshMinutes, forKey: "refreshMinutes") }
    }
    @Published var showBalanceInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showBalanceInMenuBar, forKey: "showBalanceInMenuBar") }
    }
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    static let refreshChoices = [5, 10, 15, 30, 60]

    var accent: Accent { Accent.named(accentId) }

    init() {
        let d = UserDefaults.standard
        accentId = d.string(forKey: "accentId") ?? "indigo"
        refreshMinutes = d.object(forKey: "refreshMinutes") as? Int ?? 15
        showBalanceInMenuBar = d.object(forKey: "showBalanceInMenuBar") as? Bool ?? true
        launchAtLogin = d.object(forKey: "launchAtLogin") as? Bool ?? false
    }
}
