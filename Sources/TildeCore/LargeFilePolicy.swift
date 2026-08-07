import Foundation

public enum LargeFileDisposition: Equatable, Sendable {
    case standard
    case largeFileMode
    case exceedsValidatedLimit
}

public struct LargeFilePolicy: Equatable, Sendable {
    public var largeFileThresholdBytes: Int
    public var maximumValidatedEditorBytes: Int
    public var maximumMarkdownPreviewBytes: Int

    public init(
        largeFileThresholdBytes: Int,
        maximumValidatedEditorBytes: Int,
        maximumMarkdownPreviewBytes: Int
    ) {
        precondition(largeFileThresholdBytes > 0)
        precondition(maximumValidatedEditorBytes >= largeFileThresholdBytes)
        precondition(maximumMarkdownPreviewBytes > 0)
        self.largeFileThresholdBytes = largeFileThresholdBytes
        self.maximumValidatedEditorBytes = maximumValidatedEditorBytes
        self.maximumMarkdownPreviewBytes = maximumMarkdownPreviewBytes
    }

    public static let measuredBaseline = LargeFilePolicy(
        largeFileThresholdBytes: 50 * 1_024 * 1_024,
        maximumValidatedEditorBytes: 100 * 1_024 * 1_024,
        maximumMarkdownPreviewBytes: 5 * 1_024 * 1_024
    )

    public func disposition(forByteCount byteCount: Int) -> LargeFileDisposition {
        if byteCount > maximumValidatedEditorBytes {
            return .exceedsValidatedLimit
        }
        if byteCount >= largeFileThresholdBytes {
            return .largeFileMode
        }
        return .standard
    }

    public func allowsMarkdownPreview(utf8ByteCount: Int) -> Bool {
        utf8ByteCount <= maximumMarkdownPreviewBytes
    }
}
