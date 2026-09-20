<div align="center">

<img src="docs/icon.png" width="128" alt="Horizon" />

# Horizon

### Your balance, and what it is about to do next.

A native macOS menu bar app that reads your Investec account and forecasts where
your balance is heading, with the reasoning shown.

<br />

![macOS](https://img.shields.io/badge/macOS-14%2B-1d1d1f?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6-1d1d1f?style=for-the-badge&logo=swift&logoColor=c88a4a)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-1d1d1f?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-c88a4a?style=for-the-badge)

**[Download](https://github.com/Nevvyboi/Horizon/releases/latest) · [Report an issue](https://github.com/Nevvyboi/Horizon/issues)**

</div>

<br />

> Most banking apps tell you what already happened. Horizon tells you what happens next.
> One glance, about two seconds: **current balance, future balance, and what caused the change.**

<br />

<div align="center">
  <img src="docs/settings.png" width="300" alt="Horizon settings" />
</div>

<br />

## What it does

|  |  |
| --- | --- |
| **Balance now** | Your available balance, live in the menu bar next to the zebra. |
| **Balance next** | A 30 day projection built from your real recurring payments and spending. |
| **Recurring radar** | Finds debit orders, subscriptions and salary, with a confidence score. |
| **Financial weather** | Comfortable, getting tight, or low buffer, from your projected minimum. |
| **Explain everything** | Every number opens into the assumptions behind it. No black box. |
| **What if?** | Simulate a purchase, a late salary, or cutting back, and watch the curve move. |
| **Make it yours** | Six accent themes, refresh interval, launch at login. |

<br />

## How the forecast works

No black box. Every figure traces back to a step in
[`ForecastEngine.swift`](Sources/Horizon/ForecastEngine.swift):

1. Start from the current **available balance**.
2. **Find recurring payments and income.** A merchant only counts once it has fired three
   or more times on a steady interval (5 to 45 days). Regularity is scored, so noisy card
   spending at the same shop fails the test and is ignored.
3. **Estimate everyday spending** from the average non recurring outflow over 60 days.
4. Lay the recurring events onto a **calendar** across the next 30 days.
5. Add the estimated daily spend on top.
6. Walk **day by day** to get a projected balance for every day.
7. Find the **lowest point**, the number that actually matters.
8. Surface the **assumptions** and any risks.

Scenarios re run the same pipeline with the event list nudged, so a scenario is always
explainable in the same terms as the base forecast.

<details>
<summary><b>Which Investec data it uses</b></summary>

<br />

Investec Private Banking API, read only:

- `GET /za/pb/v1/accounts`
- `GET /za/pb/v1/accounts/{id}/balance`
- `GET /za/pb/v1/accounts/{id}/transactions`

OAuth2 client credentials (Basic auth plus `x-api-key`, `scope=accounts`). Sandbox serves
the token and the data from `openapisandbox.investec.com`; production serves both from
`openapi.investec.com`. Horizon never calls a payment or transfer endpoint.

Being a native app, it talks to Investec directly. There is no proxy and no browser, so
your keys stay in the macOS Keychain.

</details>

<details>
<summary><b>What it assumes</b></summary>

<br />

- Recurring payments continue at their detected amount and cadence.
- Everyday spending resembles the last 60 days on average.
- The next salary lands on its detected cadence, so a day or two of drift is possible.
- One account is forecast at a time.

Forecasts are projections, not guarantees. The interface says projected and expected,
never "you will have".

</details>

<br />

## Connect your account

On first run Horizon offers two ways in:

- **Investec sandbox**, to try it instantly with the shared Mr Smith test account.
- **Your Investec account**, using your own keys from Investec Online, then Manage,
  Investec Developer, Individual Connections, Create new API key.

Keys are stored in the **macOS Keychain**. They are never written to disk in the clear and
never committed.

<br />

## Build it yourself

Requires macOS 14 or later and the Swift toolchain (Xcode or the Command Line Tools).

```bash
git clone https://github.com/Nevvyboi/Horizon.git
cd Horizon
./scripts/bundle.sh
open build/Horizon.app
```

`scripts/bundle.sh` builds a release binary with Swift Package Manager and wraps it in a
proper `.app`, as an agent app so it lives only in the menu bar with no Dock icon.

<br />

## How it is put together

```
Sources/Horizon/
  HorizonApp.swift      MenuBarExtra entry point
  AppState.swift        loading, refreshing, scenario building
  InvestecClient.swift  OAuth2 and the read only endpoints
  ForecastEngine.swift  recurring detection and the projection
  Keychain.swift        credential storage
  Models.swift          the shared shapes
  Theme.swift           accent themes
  RootView / FutureView / SettingsView / OnboardingView
```

<br />

## What it will not do

- Move money. No payments, transfers or trades. Read only, always.
- Give financial advice. Scenarios are calculations, not recommendations.
- Store your credentials anywhere but the Keychain.
- Pretend a projection is a promise.

<br />

## Licence

MIT. See [LICENSE](LICENSE).

<div align="center"><sub>Built for the Investec Q3 2026 "Future You" bounty.</sub></div>
