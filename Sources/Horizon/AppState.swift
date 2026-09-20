import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var connected = false
    @Published var loading = false
    @Published var errorMessage: String?

    @Published var account: Account?
    @Published var balance: Balance?
    @Published var transactions: [Transaction] = []
    @Published var forecast: Forecast?
    @Published var lastUpdated: Date?
    @Published var usingProduction = false

    private var client: InvestecClient?
    private var refreshTask: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()
    let settings = Settings()

    var today: Date { Day.start(Date()) }

    init() {
        // Settings is its own observable object, so without this the views
        // watching AppState never hear about an accent or interval change.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        // Reconnect silently if the user has connected before.
        if let creds = Keychain.load() {
            Task { await connect(with: creds, persist: false) }
        }
    }

    // MARK: - Connecting

    func connect(with creds: Credentials, persist: Bool = true) async {
        loading = true
        errorMessage = nil
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
            self.balance = bal
            self.transactions = RecurringDetector.annotate(rawTx, today: today)
            self.usingProduction = creds.production
            rebuildForecast()
            self.lastUpdated = Date()
            self.connected = true
            if persist { Keychain.save(creds) }
            scheduleRefresh()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    func refresh() async {
        guard let client, let account else { return }
        loading = true
        do {
            async let balanceCall = client.balance(accountId: account.id)
            async let txCall = client.transactions(accountId: account.id)
            let (bal, rawTx) = try await (balanceCall, txCall)
            self.balance = bal
            self.transactions = RecurringDetector.annotate(rawTx, today: today)
            rebuildForecast()
            self.lastUpdated = Date()
            self.errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
        transactions = []
        forecast = nil
        lastUpdated = nil
        connected = false
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

    var glance: GlanceStats? {
        guard let forecast else { return nil }
        return ForecastEngine.glance(forecast, transactions: transactions, today: today)
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
        return Money.short(balance.available)
    }
}
