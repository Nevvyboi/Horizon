import Foundation

/// Looks up the public IP address this Mac appears as, so the user can paste it
/// into Investec's API key allowlist and have the key refuse to work anywhere
/// else.
///
/// This is the one call Horizon makes to something other than Investec. It
/// sends no account data, it only asks "what address am I coming from", and it
/// only runs when the user opens the allowlist step or taps refresh.
enum PublicIP {
    private struct Response: Decodable { let ip: String }

    static func fetch() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }
        return parsed.ip
    }
}
