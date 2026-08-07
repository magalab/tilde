import Foundation
import TildeCore

public enum TextDocumentError: LocalizedError, Equatable, Sendable {
    case fileDeletedRequiresSaveAs
    case fileReadOnlyRequiresSaveAs
    case conflictRequiresResolution
    case reopenWouldDiscardChanges
    case fileExceedsValidatedLimit(actualBytes: Int, maximumBytes: Int)

    public var errorDescription: String? {
        switch self {
        case .fileDeletedRequiresSaveAs:
            L10n.string("The original file was deleted. Use Save As to keep the in-memory document.")
        case .fileReadOnlyRequiresSaveAs:
            L10n.string("The original file is read-only. Use Save As to write to another location.")
        case .conflictRequiresResolution:
            L10n.string("The file changed on disk. Resolve the conflict before overwriting it.")
        case .reopenWouldDiscardChanges:
            L10n.string("Save or discard the current edits before reopening with another encoding.")
        case let .fileExceedsValidatedLimit(actualBytes, maximumBytes):
            L10n.format(
                "This file is %@, which exceeds Tilde's validated v1 limit of %@.",
                ByteCountFormatter.string(fromByteCount: Int64(actualBytes), countStyle: .file),
                ByteCountFormatter.string(fromByteCount: Int64(maximumBytes), countStyle: .file)
            )
        }
    }
}
