import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var connected = false
    @Published var loading = false
    @Published var errorMessage: String?
    /// Plain language things to check, shown under the error.
    @Published var errorHints: [String] = []
    /// Whether to offer the IP allowlist alongside the error.
    @Published var errorMightBeIP = false

    @Published var account: Account?
    @Published var balance: Balance?
    @Published var transactions: [Transaction] = []
    @Published var forecast: Forecast?
    @Published var lastUpdated: Date?
    @Published var usingProduction = false

    /// Whether the owner has proved who they are during this visit. Reset
    /// every time the popover closes, so walking away relocks it.
    @Published var unlocked = false

    /// Exactly what the bank last reported, before the app's corrections.
    private var rawBalance: Balance?

    private var client: InvestecClient?
    private var refreshTask: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()
    let settings = Settings()

    var today: Date { Day.start(Date()) }

    init() {
        // Apply the saved light/dark choice to the whole app up front.
        Settings.applyAppearance(settings.appearance)

        // Settings is its own observable object, so without this the views
        // watching AppState never hear about an accent or interval change.
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                // objectWillChange fires before the new value lands, so let
                // the change settle before reading it back.
                Task { @MainActor in self?.reapplyBalanceSettings() }
            }
            .store(in: &bag)

        // Reconnect silently if the user has connected before.
        //
        // Off the main thread, because reading the Keychain can put a system
        // password prompt on screen and blocks until it is answered. Doing
        // that here on the main thread stops SwiftUI ever building the scene,
        // so the app runs with no menu bar icon at all and looks like it
        // failed to launch. Ad hoc signing changes on every rebuild and the
        // Keychain item is bound to the signature, so that prompt is routine.
        Task.detached(priority: .userInitiated) {
            guard let creds = Keychain.load() else { return }
            await self.connect(with: creds, persist: false)
        }
    }

    // MARK: - Connecting

    func connect(with creds: Credentials, persist: Bool = true, allowFallback: Bool = true) async {
        loading = true
        clearError()
        let client = InvestecClient(credentials: creds)
        do {
            let accounts = try await client.accounts()
            guard let first = accounts.first else {
                throw InvestecClient.ClientError.malformed
            }
            async let balanceCall = client.balance(accountId: first.id)
            async let txCall = client.transactions(accountId: first.id)
            let (bal, rawTx) = try await (balanceCall, txCall)

            self.client = client
            self.account = first
            self.transactions = RecurringDetector.annotate(rawTx, today: today)
            self.rawBalance = bal
            self.balance = adjusted(bal)
            self.usingProduction = creds.production
            rebuildForecast()
            self.lastUpdated = Date()
            self.connected = true
            if persist { Keychain.save(creds) }
            scheduleRefresh()
        } catch {
            // Keys the user attaches are assumed to be production. If Investec
            // rejects them there they may well be sandbox keys, so try the
            // other host before reporting a failure. Saves asking the user to
            // pick an environment they should not have to think about.
            if allowFallback, creds.production,
               (error as? InvestecClient.ClientError)?.isBadCredentials == true {
                var alternative = creds
                alternative.production = false
                await connect(with: alternative, persist: persist, allowFallback: false)
                return
            }
            report(error)
        }
        loading = false
    }

    /// Turn a thrown error into something the onboarding screen can explain.
    private func report(_ error: Error) {
        let client = error as? InvestecClient.ClientError
        errorMessage = client?.errorDescription
            ?? (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        errorHints = client?.hints ?? []
        errorMightBeIP = client?.mightBeIPAllowlist ?? false
    }

    func clearError() {
        errorMessage = nil
        errorHints = []
        errorMightBeIP = false
    }

    func refresh() async {
        guard let client, let account else { return }
        loading = true
        do {
            async let balanceCall = client.balance(accountId: account.id)
            async let txCall = client.transactions(accountId: account.id)
            let (bal, rawTx) = try await (balanceCall, txCall)
            self.transactions = RecurringDetector.annotate(rawTx, today: today)
            self.rawBalance = bal
            self.balance = adjusted(bal)
            rebuildForecast()
            self.lastUpdated = Date()
            clearError()
        } catch {
            report(error)
        }
        loading = false
    }

    func disconnect() {
        refreshTask?.cancel()
        refreshTask = nil
        Keychain.clear()
        client = nil
        account = nil
        balance = nil
        rawBalance = nil
        transactions = []
        forecast = nil
        lastUpdated = nil
        connected = false
    }

    /// Turn what the bank reported into what the app should reason about.
    ///
    /// Two corrections. The balance endpoint reports what has posted, so a
    /// card swipe from this morning, or anything from a merchant that only
    /// settles once a week, is missing from it and has to be read off the
    /// transaction feed instead. And if the user has told us their reported
    /// balance has a credit facility folded into it, the borrowed part is
    /// taken back out so the figure is their own money.
    private func adjusted(_ balance: Balance) -> Balance {
        var out = balance
        out.pending = transactions
            .filter(\.isPending)
            .reduce(0) { $0 + $1.amount }
        out.facilityInBalance = settings.facilityToStrip
        return out
    }

    /// Shut the app again. Called when the popover closes, and when locking
    /// is switched on so it takes effect without waiting for the next visit.
    func lock() {
        unlocked = false
    }

    /// Whether the popover should be showing the lock screen right now.
    var isLocked: Bool {
        settings.requireUnlock && !unlocked
    }

    /// Reapply the settings to the balance the bank last gave us, without
    /// going back to the network.
    func reapplyBalanceSettings() {
        guard let rawBalance else { return }
        balance = adjusted(rawBalance)
        rebuildForecast()
    }

    private func rebuildForecast() {
        guard let balance else { return }
        forecast = ForecastEngine.build(
            balance: balance,
            transactions: transactions,
            today: today
        )
    }

    /// Build a forecast with a scenario layered on, without disturbing the base.
    func forecast(with scenario: Scenario?) -> Forecast? {
        guard let balance else { return nil }
        guard let scenario else { return forecast }
        return ForecastEngine.build(
            balance: balance,
            transactions: transactions,
            today: today,
            scenario: scenario
        )
    }

    /// Most recent transactions that have actually happened, newest first.
    /// The feed can carry forward-dated postings, which do not belong in a
    /// list called "latest".
    func recentTransactions(limit: Int = 5) -> [Transaction] {
        transactions
            .filter { Day.between(today, $0.date) <= 0 }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    var glance: GlanceStats? {
        guard let forecast else { return nil }
        return ForecastEngine.glance(forecast, transactions: transactions, today: today,
                                     floor: balance?.floor ?? 0)
    }

    // MARK: - Auto refresh

    func scheduleRefresh() {
        refreshTask?.cancel()
        let minutes = settings.refreshMinutes
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
                if Task.isCancelled { return }
                await self?.refresh()
            }
        }
    }

    /// Short text for the menu bar, e.g. "R33 607".
    var menuBarTitle: String {
        guard settings.showBalanceInMenuBar, let balance else { return "Horizon" }
        return Money.short(balance.settled)
    }
}
