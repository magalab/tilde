import Foundation

public enum TextCodecError: LocalizedError, Equatable, Sendable {
    case unsupportedOrInvalidEncoding
    case malformedUTF16
    case suspectedBinaryFile
    case mixedLineEndingsRequireSelection

    public var errorDescription: String? {
        switch self {
        case .unsupportedOrInvalidEncoding:
            L10n.string("The file is not valid UTF-8 or UTF-16. Choose an encoding to reopen it.")
        case .malformedUTF16:
            L10n.string("The file contains an invalid UTF-16 byte or surrogate sequence.")
        case .suspectedBinaryFile:
            L10n.string("The file appears to contain binary data and cannot be opened as plain text.")
        case .mixedLineEndingsRequireSelection:
            L10n.string("This edited file contains mixed line endings. Choose LF, CRLF, or CR before saving.")
        }
    }
}
