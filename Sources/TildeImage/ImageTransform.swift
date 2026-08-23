import AppKit
import CoreGraphics

public enum ImageTransform {
    /// Copies a raster-backed AppKit image into an explicitly sized bitmap while
    /// reversing its vertical orientation. The explicit pixel dimensions preserve
    /// high-resolution Mermaid output instead of rasterizing through deprecated
    /// `lockFocus()` APIs. Vector-only images return `nil`; Mermaid's AppKit renderer
    /// currently returns a raster-backed image, which keeps this conversion deterministic.
    public static func verticallyFlipped(_ image: NSImage, scale: CGFloat = 1) -> NSImage? {
        let logicalSize = image.size
        guard logicalSize.width > 0, logicalSize.height > 0, scale > 0 else {
            return nil
        }

        var proposedRect = NSRect(origin: .zero, size: logicalSize)
        guard let source = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            return nil
        }

        let pixelWidth = max(1, Int((logicalSize.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((logicalSize.height * scale).rounded(.up)))
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: 1, y: -1)
        context.draw(
            source,
            in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        )

        guard let flipped = context.makeImage() else { return nil }
        return NSImage(cgImage: flipped, size: logicalSize)
    }
}
