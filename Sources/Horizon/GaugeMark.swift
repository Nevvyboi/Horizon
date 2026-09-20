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
                .stroke(color, lineWidth: line)
            Circle()
                .fill(color)
                .frame(width: line * 0.95, height: line * 0.95)
                .offset(y: -(size - line) / 2)
        }
        .frame(width: size, height: size)
    }

    /// A template image for the menu bar.
    ///
    /// Drawn with AppKit rather than ImageRenderer: a template uses only the
    /// alpha channel, and the renderer hands back an opaque canvas, which the
    /// menu bar then paints as a solid block instead of a ring.
    static func menuBarImage(size: CGFloat = 15) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let line = max(1.7, size * 0.17)
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: line / 2 + 0.5, dy: line / 2 + 0.5))
            ring.lineWidth = line
            NSColor.black.setStroke()
            ring.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
