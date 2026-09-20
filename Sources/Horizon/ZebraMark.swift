import SwiftUI
import AppKit

/// The Horizon mark: a zebra, after Investec's own. Shipped as artwork rather
/// than drawn with shapes, because a hand-rolled silhouette does not read as a
/// zebra at these sizes.
enum ZebraAsset {
    static let image: NSImage? = {
        guard let path = Bundle.main.path(forResource: "Zebra", ofType: "png") else { return nil }
        let image = NSImage(contentsOfFile: path)
        image?.size = NSSize(width: 64, height: 64)
        return image
    }()

    /// A copy sized for the menu bar. Kept in colour rather than as a template
    /// so the stripes survive; a tinted silhouette turns into a blob at 18pt.
    @MainActor
    static func menuBar(size: CGFloat = 17) -> NSImage {
        guard let base = image?.copy() as? NSImage else { return NSImage() }
        base.size = NSSize(width: size, height: size)
        return base
    }
}

struct ZebraMark: View {
    var size: CGFloat = 16
    /// Kept for call sites that tint the mark; the artwork is full colour, so
    /// this only tints the fallback glyph.
    var color: Color = .primary

    var body: some View {
        if let image = ZebraAsset.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.8))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }
}
