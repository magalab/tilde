import Foundation
import TildeCore

public struct DocumentSnapshot: Equatable, Sendable {
    public let text: String
    public let revision: UInt64
    public let encoding: DetectedEncoding
    public let lineEnding: LineEnding
    public let documentType: String
    public let fileURL: URL?
    public let utf8ByteCount: Int

    public init(
        text: String,
        revision: UInt64,
        encoding: DetectedEncoding,
        lineEnding: LineEnding,
        documentType: String,
        fileURL: URL?,
        utf8ByteCount: Int? = nil
    ) {
        self.text = text
        self.revision = revision
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.documentType = documentType
        self.fileURL = fileURL
        self.utf8ByteCount = utf8ByteCount ?? text.utf8.count
    }
}
