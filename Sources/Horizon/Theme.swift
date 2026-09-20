import SwiftUI

/// Accent themes. The whole interface pulls its accent from here, so a rebrand
/// is one tap. Money in / money out stay green and red, because those carry
/// meaning rather than branding.
struct Accent: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color

    static let all: [Accent] = [
        Accent(id: "bronze",   name: "Bronze",   color: Color(red: 0.78, green: 0.54, blue: 0.29)),
        Accent(id: "azure",    name: "Azure",    color: Color(red: 0.29, green: 0.59, blue: 0.88)),
        Accent(id: "violet",   name: "Violet",   color: Color(red: 0.55, green: 0.48, blue: 0.85)),
        Accent(id: "emerald",  name: "Emerald",  color: Color(red: 0.25, green: 0.68, blue: 0.50)),
        Accent(id: "rose",     name: "Rose",     color: Color(red: 0.85, green: 0.39, blue: 0.48)),
        Accent(id: "graphite", name: "Graphite", color: Color(red: 0.60, green: 0.64, blue: 0.70)),
    ]

    static func named(_ id: String) -> Accent {
        all.first { $0.id == id } ?? all[0]
    }
}

enum Palette {
    static let moneyIn = Color(red: 0.42, green: 0.76, blue: 0.56)
    static let moneyOut = Color(red: 0.85, green: 0.38, blue: 0.33)
    static let warn = Color(red: 0.82, green: 0.64, blue: 0.33)

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
        accentId = d.string(forKey: "accentId") ?? "bronze"
        refreshMinutes = d.object(forKey: "refreshMinutes") as? Int ?? 15
        showBalanceInMenuBar = d.object(forKey: "showBalanceInMenuBar") as? Bool ?? true
        launchAtLogin = d.object(forKey: "launchAtLogin") as? Bool ?? false
    }
}
