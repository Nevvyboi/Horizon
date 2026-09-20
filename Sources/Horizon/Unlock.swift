import SwiftUI
import LocalAuthentication

/// Holding the app shut until the owner proves who they are.
///
/// The menu bar is a public place: the popover opens on a click, and anyone
/// who walks past an unlocked laptop can read a balance off it. This puts
/// Touch ID, or the login password when there is no sensor, in front of it.
enum Unlock {

    /// Whether this Mac has a usable fingerprint sensor, so the prompt can be
    /// described honestly rather than promising Touch ID to a machine
    /// without one.
    static var hasBiometrics: Bool {
        var error: NSError?
        let ok = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return ok && error == nil
    }

    static var methodDescription: String {
        hasBiometrics ? "Touch ID or your password" : "Your login password"
    }

    /// Ask the system to confirm the owner.
    ///
    /// deviceOwnerAuthentication rather than the biometrics only policy, so a
    /// Mac without a sensor, or a finger the sensor will not read, falls back
    /// to the password instead of failing outright.
    @MainActor
    static func authenticate(reason: String = "unlock Horizon and see your balance") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Not now"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No way to authenticate at all. Refusing entry here would lock
            // the owner out of their own app with no way back, so let them in.
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

/// What the popover shows while it is locked.
struct LockView: View {
    @EnvironmentObject var state: AppState
    var accent: Color

    @State private var working = false
    @State private var refused = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 62, height: 62)
                Image(systemName: refused ? "lock.trianglebadge.exclamationmark" : "lock.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accent)
            }

            Text("Horizon is locked")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 14)

            Text(refused
                 ? "That did not go through. Try again when you are ready."
                 : "\(Unlock.methodDescription) will show your balance.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
                .padding(.horizontal, 24)

            Button(action: attempt) {
                HStack(spacing: 6) {
                    if working {
                        ProgressView().controlSize(.mini).scaleEffect(0.6)
                    } else {
                        Image(systemName: Unlock.hasBiometrics ? "touchid" : "key")
                            .font(.system(size: 11))
                    }
                    Text(refused ? "Try again" : "Unlock")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .disabled(working)
            .padding(.top, 18)
            .padding(.horizontal, 44)

            Spacer()

            Text("Locking can be turned off in settings.")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 520)
        .padding(16)
        // Ask straight away, so opening the popover is a single gesture
        // rather than a click followed by another click.
        .task { await run() }
    }

    private func attempt() {
        Task { await run() }
    }

    private func run() async {
        guard !working, !state.unlocked else { return }
        working = true
        let ok = await Unlock.authenticate()
        working = false
        if ok {
            refused = false
            state.unlocked = true
        } else {
            refused = true
        }
    }
}
