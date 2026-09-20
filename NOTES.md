# Notes

Things that cost real time while building this, written down so they only
have to be learned once.

## Investec API

**Sandbox and production are different hosts.** Sandbox serves both the token
and the data from `openapisandbox.investec.com`. Production serves both from
`openapi.investec.com`, same paths. Point one environment's keys at the other
host and every call fails auth while looking, from the outside, like an empty
account. Horizon assumes keys are production and quietly retries against
sandbox if they are refused, so nobody has to choose an environment.

**Transactions are in rands, as plain numbers.** Values arrive as `8500` or
`152.75`, not cents. Keep the number as the wire gives it and take the sign
from the `DEBIT` or `CREDIT` type. Multiplying by 100 to be safe puts you out
by a factor of 100.

**Descriptions carry runs of spaces.** Merchant strings come through padded,
so they get split and rejoined before display.

**The balance endpoint reports what has posted.** Anything authorised but not
yet claimed by the merchant is missing from it and has to be read off the
transaction feed, where it is marked pending. Some merchants only settle
weekly, so this can be days out of date. See `AppState.adjusted`.

**Pending card purchases need asking for.** The transactions endpoint leaves
them out by default. Append `?includePending=true` and they arrive with
`status: PENDING`. Measured against the sandbox: the plain call returns 263
transactions, all posted; with the parameter, 266, three of them pending.
Pending records have a null `postingDate` and an empty `uuid`, so date parsing
has to fall back to `transactionDate`.

This one is quietly expensive. Without the parameter the pending total reads
zero, and because the credit facility is derived from the gap between the
available and current figures, the facility comes out short by exactly
whatever is being held. A real account with R136.16 of card purchases waiting
to settle showed a R10 000 facility as R9 864, and the balance looked R136
healthier than it was. Everything downstream of the balance inherits that.

**The available figure is net of holds.** Confirmed by arithmetic against a
real account rather than from documentation: available R9 387.02 = 10 000
facility - 476.82 posted - 136.16 pending. So the pending amount has to be
added back when working the facility out.

**A credit facility may or may not be visible.** Some accounts report it
separately, which leaves a gap between the available and current figures that
can be measured. Others report a single number with the facility already
counted in, and nothing in the response distinguishes borrowed money from
your own. That case cannot be detected, only declared, hence the setting.

## Forecasting

**Regularity beats volume for recurring detection.** Early versions flagged
supermarkets and ride hailing as recurring because they appear often. They are
frequent but irregular. Require three or more occurrences and a tight
interval: score regularity as `1 - spread / (cadence * 0.5)`, drop anything
below 0.6, and only then blend in volume, with a confidence threshold of 0.75.
A real debit order lands on nearly the same interval every month and sails
through; noisy card spend does not.

**Forecast the minimum, not the endpoint.** For a scenario like "salary
arrives three days late" the balance 30 days out is unchanged, because the
salary still lands inside the window. What changes is how far you dip before
it does. Comparing endpoints made a late salary look free.

**Never measure comfort against borrowed money.** The comfort threshold falls
back to a share of your own balance, not the available figure, or a large
facility makes a struggling account look healthy.

## SwiftUI and AppKit

**MenuBarExtra collapses around a ScrollView.** With
`.menuBarExtraStyle(.window)` the popover sizes itself to its content, and a
ScrollView has no intrinsic height, so a root ScrollView opens as a two pixel
sliver. Give it an explicit `.frame(height:)`.

**preferredColorScheme does not reach the menu bar window.** It is system
chrome. Set `NSApp.appearance` instead.

**Template images use only the alpha channel.** `ImageRenderer` hands back an
opaque canvas, which the menu bar then paints as a solid block instead of a
ring, so the menu bar mark is drawn with `NSBezierPath`.

**Nested observable objects need forwarding.** `Settings` is its own
`ObservableObject`, so views watching `AppState` hear nothing about an accent
or interval change until `objectWillChange` is piped through.

**The compiler gives up on busy grid cells.** A cell with several conditional
modifiers inside a `ForEach` body fails to type check in reasonable time. Pull
it out into its own small `View`.

**Keyed ForEach by index for repeated labels.** Weekday initials deduplicate
and collapse under `id: \.self`.

**Never read the Keychain on the main thread at startup.** `SecItemCopyMatching`
blocks while macOS puts up a password prompt, and doing that during
`AppState.init` means SwiftUI never builds the scene. The process runs with no
menu bar icon at all and looks like it failed to launch. It hides well because
the prompt only appears when the code signature changes, which for an ad hoc
build is every rebuild. Load in a detached task.

## Credentials

Keys live in the macOS Keychain and nowhere else: not in the bundle, not in
UserDefaults, not on disk. The repo contains no credentials of any kind,
including test ones, so the sandbox option asks you to copy Investec's
published test keys across yourself.

Ad hoc signing changes the code signature on every rebuild, and Keychain
access control is bound to that signature, so a freshly built copy prompts for
permission again. That is expected, not a bug.
