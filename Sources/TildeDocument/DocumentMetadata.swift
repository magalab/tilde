import Foundation
import TildeCore

public struct DocumentMetadata: Equatable, Sendable {
    public var encoding: DetectedEncoding
    public var lineEndings: LineEndingProfile
    public var selectedLineEnding: LineEnding?
    public var documentType: String
    public var sourceByteCount: Int

    public init(
        encoding: DetectedEncoding = .newDocumentUTF8,
        lineEndings: LineEndingProfile = LineEndingProfile(),
        selectedLineEnding: LineEnding? = .lf,
        documentType: String = TildeDocumentType.plainText,
        sourceByteCount: Int = 0
    ) {
        self.encoding = encoding
        self.lineEndings = lineEndings
        self.selectedLineEnding = selectedLineEnding
        self.documentType = documentType
        self.sourceByteCount = sourceByteCount
    }
}

public enum TildeDocumentType {
    public static let plainText = "public.plain-text"
    public static let markdown = "net.daringfireball.markdown"

    public static func type(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "md", "markdown": markdown
        default: plainText
        }
    }
}

public enum MarkdownPreviewAvailability: Equatable, Sendable {
    case available
    case notMarkdown
    case sourceTooLarge
}
