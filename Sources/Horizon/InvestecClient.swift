import Foundation

/// Investec wraps every payload in a `data` object.
private struct Envelope<U: Decodable>: Decodable { let data: U }

/// Read-only Investec Private Banking API client.
///
/// Native app, so there is no CORS problem and no proxy: the credentials live
/// in the Keychain and the requests go straight to Investec. This client never
/// touches a payment or transfer endpoint.
///
/// Sandbox serves both the token and the data from openapisandbox.investec.com.
/// Production serves both from openapi.investec.com. Mixing the two is the
/// classic way to get an auth failure that looks like an empty account.
actor InvestecClient {

    enum ClientError: LocalizedError {
        case badCredentials
        case forbidden          // 403, usually the IP allowlist or key permissions
        case notFound           // 404, usually the wrong environment
        case rateLimited        // 429
        case server(Int)        // 5xx, Investec's side
        case http(Int)
        case offline(String)
        case malformed

        var errorDescription: String? {
            switch self {
            case .badCredentials:
                return "Investec did not accept those keys."
            case .forbidden:
                return "Investec accepted the keys but refused the request."
            case .notFound:
                return "Investec could not find that account."
            case .rateLimited:
                return "Too many requests to Investec just now."
            case .server(let code):
                return "Investec is having trouble on their side (\(code))."
            case .http(let code):
                return "Investec returned an unexpected error (\(code))."
            case .offline:
                return "Could not reach Investec."
            case .malformed:
                return "Could not read Investec's response."
            }
        }

        /// Plain language things the user can actually check.
        var hints: [String] {
            switch self {
            case .badCredentials:
                return [
                    "Check the Client ID, Client Secret and API key for a stray space or a missing character.",
                    "Make sure the API key is still active in Investec Online.",
                    "Keys are per profile, so confirm you copied them from the right one.",
                ]
            case .forbidden:
                return [
                    "This device's IP address may not be on the key's allowlist. That is the most common cause.",
                    "The key may not have permission for this account. Check the accounts it was given access to.",
                ]
            case .notFound:
                return [
                    "The key may belong to a different environment than the one being called.",
                    "Confirm the account is still open and visible to this key.",
                ]
            case .rateLimited:
                return ["Wait a minute and try again. Horizon also refreshes on a timer, so it will retry on its own."]
            case .server, .http:
                return ["This is usually temporary. Try again shortly.", "If it persists, check the Investec developer community for an outage."]
            case .offline:
                return ["Check your internet connection.", "If you are on a VPN, note that it changes the IP Investec sees."]
            case .malformed:
                return ["Investec returned something unexpected. Trying again usually clears it."]
            }
        }

        /// Whether the IP allowlist is worth showing alongside the error.
        var mightBeIPAllowlist: Bool {
            switch self {
            case .forbidden, .offline: return true
            default: return false
            }
        }

        var isBadCredentials: Bool {
            if case .badCredentials = self { return true }
            return false
        }
    }

    /// Turn a status code into something the user can act on.
    private static func mapStatus(_ code: Int) -> ClientError {
        switch code {
        case 400, 401: return .badCredentials
        case 403:      return .forbidden
        case 404:      return .notFound
        case 429:      return .rateLimited
        case 500...599: return .server(code)
        default:       return .http(code)
        }
    }

    private var creds: Credentials
    private var token: String?
    private var tokenExpiry: Date = .distantPast

    init(credentials: Credentials) {
        self.creds = credentials
    }

    func update(credentials: Credentials) {
        self.creds = credentials
        self.token = nil
        self.tokenExpiry = .distantPast
    }

    private var host: String {
        creds.production ? "https://openapi.investec.com" : "https://openapisandbox.investec.com"
    }
    private var tokenURL: URL { URL(string: host + "/identity/v2/oauth2/token")! }
    private var apiBase: String { host + "/za/pb/v1" }

    // MARK: - Auth

    private func accessToken() async throws -> String {
        if let t = token, Date() < tokenExpiry { return t }

        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        let basic = Data("\(creds.clientId):\(creds.secret)".utf8).base64EncodedString()
        req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        req.setValue(creds.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data("grant_type=client_credentials&scope=accounts".utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ClientError.offline(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw ClientError.malformed }
        guard http.statusCode == 200 else { throw Self.mapStatus(http.statusCode) }
        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Int?
        }
        guard let parsed = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw ClientError.malformed
        }
        token = parsed.access_token
        // Refresh a minute before the real expiry.
        tokenExpiry = Date().addingTimeInterval(Double((parsed.expires_in ?? 1800) - 60))
        return parsed.access_token
    }

    private func get<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        let t = try await accessToken()
        var req = URLRequest(url: URL(string: apiBase + path)!)
        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        req.setValue(creds.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ClientError.offline(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw ClientError.malformed }
        guard http.statusCode == 200 else { throw Self.mapStatus(http.statusCode) }
        guard let parsed = try? JSONDecoder().decode(Envelope<T>.self, from: data) else {
            throw ClientError.malformed
        }
        return parsed.data
    }

    // MARK: - Wire shapes

    private struct RawAccounts: Decodable {
        struct RawAccount: Decodable {
            let accountId: String
            let accountNumber: String?
            let accountName: String?
            let referenceName: String?
            let currency: String?
        }
        let accounts: [RawAccount]
    }

    private struct RawBalance: Decodable {
        let currentBalance: Double
        let availableBalance: Double
        let currency: String?
    }

    private struct RawTransactions: Decodable {
        struct RawTransaction: Decodable {
            let type: String
            let status: String?
            let description: String
            let amount: Double
            let postingDate: String?
            let transactionDate: String?
        }
        let transactions: [RawTransaction]
    }

    // MARK: - Public surface

    func accounts() async throws -> [Account] {
        let raw = try await get("/accounts", as: RawAccounts.self)
        return raw.accounts.map {
            Account(
                id: $0.accountId,
                name: $0.referenceName ?? $0.accountName ?? "Account",
                number: $0.accountNumber ?? "",
                currency: $0.currency ?? "ZAR"
            )
        }
    }

    func balance(accountId: String) async throws -> Balance {
        let raw = try await get("/accounts/\(accountId)/balance", as: RawBalance.self)
        return Balance(
            current: raw.currentBalance,
            available: raw.availableBalance,
            currency: raw.currency ?? "ZAR"
        )
    }

    func transactions(accountId: String) async throws -> [Transaction] {
        let raw = try await get("/accounts/\(accountId)/transactions", as: RawTransactions.self)
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"

        return raw.transactions.enumerated().compactMap { index, t in
            let stamp = t.postingDate ?? t.transactionDate ?? ""
            guard let date = iso.date(from: String(stamp.prefix(10))) else { return nil }
            // The API talks rands as plain numbers, not cents. Keep as-is and
            // only attach a sign from the DEBIT/CREDIT type.
            let isCredit = t.type.uppercased() == "CREDIT"
            let amount = isCredit ? abs(t.amount) : -abs(t.amount)
            return Transaction(
                id: "inv-\(index)",
                date: date,
                describedAs: t.description.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " "),
                amount: amount,
                category: Categoriser.categorise(t.description, direction: isCredit ? .money_in : .money_out),
                isPending: (t.status ?? "").uppercased() == "PENDING",
                recurring: nil
            )
        }
    }
}
