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

    public init(
        allowsRawHTML: Bool,
        allowsRemoteResources: Bool,
        allowedLinkSchemes: Set<String>,
        maximumSourceBytes: Int,
        maximumOutputBytes: Int,
        maximumAttachmentBytes: Int,
        maximumAttachmentCount: Int,
        maximumImagePixels: Int
    ) {
        self.allowsRawHTML = allowsRawHTML
        self.allowsRemoteResources = allowsRemoteResources
        self.allowedLinkSchemes = allowedLinkSchemes
        self.maximumSourceBytes = maximumSourceBytes
        self.maximumOutputBytes = maximumOutputBytes
        self.maximumAttachmentBytes = maximumAttachmentBytes
        self.maximumAttachmentCount = maximumAttachmentCount
        self.maximumImagePixels = maximumImagePixels
    }

    public static let `default` = MarkdownPolicy(
        allowsRawHTML: false,
        allowsRemoteResources: false,
        allowedLinkSchemes: ["http", "https", "mailto"],
        maximumSourceBytes: 5 * 1_024 * 1_024,
        maximumOutputBytes: 10 * 1_024 * 1_024,
        maximumAttachmentBytes: 20 * 1_024 * 1_024,
        maximumAttachmentCount: 64,
        maximumImagePixels: 40_000_000
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
