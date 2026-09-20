<div align="center">

<img src="public/icon.png" width="128" alt="Horizon" />

# Horizon

### Your balance, and what it is about to do next.

A tiny glass utility for the macOS menu bar and Windows tray that forecasts where your
Investec balance is heading, and shows exactly why.

<br />

![macOS](https://img.shields.io/badge/macOS-1d1d1f?style=for-the-badge&logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-1d1d1f?style=for-the-badge&logo=windows&logoColor=white)
![Tauri](https://img.shields.io/badge/Tauri-1d1d1f?style=for-the-badge&logo=tauri&logoColor=c88a4a)
![License](https://img.shields.io/badge/License-MIT-c88a4a?style=for-the-badge)

**[⬇ Download](https://github.com/Nevvyboi/Horizon/releases/latest) · [Report an issue](https://github.com/Nevvyboi/Horizon/issues)**

</div>

<br />

> Most banking apps tell you what already happened. Horizon tells you what happens next.
> One glance, about two seconds: **current balance → future balance → what caused the change.**

<br />

## What it does

Horizon reads your Investec account (read only) and turns it into a forecast you can trust:

|  |  |
| --- | --- |
| 💰 **Balance now** | Your available balance, front and centre, in the menu bar. |
| 📉 **Balance next** | A 30 day projection built from your real recurring payments and spending. |
| 🔁 **Recurring radar** | Detects debit orders, subscriptions and salary, with a confidence score. |
| 🌤️ **Financial weather** | Comfortable, getting tight, or low buffer, from your projected minimum. |
| 🧮 **Explain everything** | Every number opens up into the assumptions behind it. No black box. |
| ⚡ **What if?** | Simulate a purchase, a late salary, or cancelling a subscription, live. |

<br />

## Download

Grab the latest build from the **[Releases](https://github.com/Nevvyboi/Horizon/releases/latest)** page:

- **macOS** · `Horizon_x.y.z_universal.dmg` (Apple Silicon and Intel)
- **Windows** · `Horizon_x.y.z_x64-setup.exe` or the `.msi`

Builds are unsigned, so on first launch allow Horizon through Gatekeeper (macOS) or
SmartScreen (Windows). You can also build it yourself, see [Run it locally](#run-it-locally).

<br />

## How the forecast works

The engine is deliberately transparent. Every figure traces back to a step
(`src/services/forecastService.ts`):

1. Start from the current **available balance**.
2. **Find recurring payments and income.** A merchant only counts as recurring after it
   fires three or more times on a steady interval (5 to 45 days). Noisy card spending at
   the same shop fails the regularity test and is ignored.
3. **Estimate everyday spending** from the average non recurring outflow over 60 days.
4. Lay the known recurring events onto a **calendar** across the next 30 days.
5. Add the estimated daily spend on top.
6. Walk **day by day** to get a projected balance for every day.
7. Find the **lowest point**, the number that actually matters.
8. Surface the **assumptions** and any risks.

Scenarios ("spend R5,000", "salary 3 days late", "cancel Netflix") re run the same pipeline
with the event list nudged, so a scenario is always explainable in the same terms.

<details>
<summary><b>Which Investec data it uses</b></summary>

<br />

Investec Private Banking API, read only:

- `GET /za/pb/v1/accounts`
- `GET /za/pb/v1/accounts/{id}/balance`
- `GET /za/pb/v1/accounts/{id}/transactions`

OAuth2 client credentials (Basic auth + `x-api-key`, `scope=accounts`). It works against the
shared sandbox out of the box, and against your own account in production when you attach
your keys. Horizon never calls a payment or transfer endpoint.

</details>

<details>
<summary><b>What it assumes</b></summary>

<br />

- Recurring payments continue at their detected amount and cadence.
- Everyday spending resembles the last 60 days on average.
- The next salary lands on its detected cadence (a day or two of drift is possible).
- One account is forecast at a time.

Forecasts are projections, not guarantees. The interface says "projected" and "expected",
never "you will have".

</details>

<br />

## Connect your account

On first run, Horizon offers two ways in:

- **Investec sandbox** · try it instantly with the shared Mr Smith test account.
- **Your Investec account** · paste your own keys from Investec Online → Manage → Investec
  Developer → Individual Connections → Create new API key.

Your keys never touch the browser bundle. The dev server (and, when packaged, the Rust
backend) holds them and proxies the read only calls.

<br />

## Run it locally

```bash
git clone https://github.com/Nevvyboi/Horizon.git
cd Horizon
npm install
cp .env.example .env      # optional, enables the live Investec sandbox
npm run dev               # http://localhost:5173
```

Package it as a real menu bar app with Tauri (needs the Rust toolchain):

```bash
npm run tauri build
```

<br />

## Built with

`React` · `TypeScript` · `Vite` · `Framer Motion` · `Tauri` · a hand rolled glass design
system. Clean service layer (`bankingService`, `transactionService`, `forecastService`) so
the mock source and the live Investec source are interchangeable.

<br />

## What it will not do

- Move money. No payments, transfers or trades. Read only, always.
- Give financial advice. Scenarios are calculations, not recommendations.
- Store your credentials in the app, the browser, or this repo.
- Pretend a projection is a promise.

<br />

## Licence

MIT. See [LICENSE](LICENSE).

<div align="center"><sub>Built for the Investec Q3 2026 "Future You" bounty.</sub></div>
