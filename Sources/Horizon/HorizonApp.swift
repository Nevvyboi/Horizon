import SwiftUI

/// Horizon lives entirely in the macOS menu bar. MenuBarExtra in .window style
/// gives a real system popover, so there is no fake desktop behind it and no
/// rectangle around the panel.
@main
struct HorizonApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(state)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: GaugeMark.menuBarImage(size: 15))
                Text(state.menuBarTitle)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
