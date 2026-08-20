import Foundation

public struct MarkdownPolicy: Equatable, Sendable {
    public var allowsRawHTML: Bool
    public var allowsRemoteResources: Bool
    public var allowedLinkSchemes: Set<String>
    public var maximumSourceBytes: Int
    public var maximumOutputBytes: Int
    public var maximumAttachmentBytes: Int
    public var maximumAttachmentCount: Int
    public var maximumImagePixels: Int
    public var maximumMermaidSourceBytes: Int
    public var maximumMermaidDiagramCount: Int
    public var maximumMermaidImagePixels: Int

    public init(
        allowsRawHTML: Bool,
        allowsRemoteResources: Bool,
        allowedLinkSchemes: Set<String>,
        maximumSourceBytes: Int,
        maximumOutputBytes: Int,
        maximumAttachmentBytes: Int,
        maximumAttachmentCount: Int,
        maximumImagePixels: Int,
        maximumMermaidSourceBytes: Int = 256 * 1_024,
        maximumMermaidDiagramCount: Int = 16,
        maximumMermaidImagePixels: Int = 8_000_000
    ) {
        self.allowsRawHTML = allowsRawHTML
        self.allowsRemoteResources = allowsRemoteResources
        self.allowedLinkSchemes = allowedLinkSchemes
        self.maximumSourceBytes = maximumSourceBytes
        self.maximumOutputBytes = maximumOutputBytes
        self.maximumAttachmentBytes = maximumAttachmentBytes
        self.maximumAttachmentCount = maximumAttachmentCount
        self.maximumImagePixels = maximumImagePixels
        self.maximumMermaidSourceBytes = maximumMermaidSourceBytes
        self.maximumMermaidDiagramCount = maximumMermaidDiagramCount
        self.maximumMermaidImagePixels = maximumMermaidImagePixels
    }

    public static let `default` = MarkdownPolicy(
        allowsRawHTML: false,
        allowsRemoteResources: false,
        allowedLinkSchemes: ["http", "https", "mailto"],
        maximumSourceBytes: 5 * 1_024 * 1_024,
        maximumOutputBytes: 10 * 1_024 * 1_024,
        maximumAttachmentBytes: 20 * 1_024 * 1_024,
        maximumAttachmentCount: 64,
        maximumImagePixels: 40_000_000,
        maximumMermaidSourceBytes: 256 * 1_024,
        maximumMermaidDiagramCount: 16,
        maximumMermaidImagePixels: 8_000_000
    )

    public func allowsLink(_ destination: String) -> Bool {
        guard let components = URLComponents(string: destination),
              let scheme = components.scheme?.lowercased()
        else {
            return true
        }
        return allowedLinkSchemes.contains(scheme)
    }

    public func allowsRemoteResource(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return true }
        if scheme == "http" || scheme == "https" {
            return allowsRemoteResources
        }
        return scheme == "file"
    }

    /// Checks the pixel dimensions of a Mermaid layout before a bitmap is allocated.
    /// Mermaid renders at a scale factor, so the layout dimensions are converted to pixels
    /// conservatively using ceiling rounding.
    public func allowsMermaidImagePixels(
        width: Double,
        height: Double,
        scale: Double = 2
    ) -> Bool {
        guard width.isFinite, height.isFinite, scale.isFinite,
              width > 0, height > 0, scale > 0,
              maximumMermaidImagePixels > 0
        else { return false }

        let pixelWidth = (width * scale).rounded(.up)
        let pixelHeight = (height * scale).rounded(.up)
        guard pixelWidth.isFinite, pixelHeight.isFinite,
              pixelWidth > 0, pixelHeight > 0
        else { return false }

        return pixelWidth * pixelHeight <= Double(maximumMermaidImagePixels)
    }
}

public enum HTMLEscaping {
    public static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
