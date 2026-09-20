import SwiftUI
import AppKit

/// The Horizon mark: the gauge ring from the app's own readouts. Drawn rather
/// than shipped as artwork so it stays crisp from 15pt in a header up to the
/// hero size, and reads as a silhouette in the menu bar.
struct GaugeMark: View {
    var size: CGFloat = 16
    var color: Color = .primary

    private var line: CGFloat { max(2, size * 0.2) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.22), lineWidth: line)
            Circle()
                .trim(from: 0, to: 0.76)
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(color)
                .frame(width: line * 0.95, height: line * 0.95)
                .offset(y: -(size - line) / 2)
        }
        .frame(width: size, height: size)
    }

    /// A template image for the menu bar, which cannot host arbitrary views.
    @MainActor
    static func menuBarImage(size: CGFloat = 15) -> NSImage {
        let renderer = ImageRenderer(content: GaugeMark(size: size, color: .black))
        renderer.scale = 3
        guard let image = renderer.nsImage else { return NSImage() }
        image.isTemplate = true
        return image
    }
}
