import Foundation

public struct MarkdownNewlineEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String

    public init(range: NSRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }
}

public enum MarkdownEditingTransformer {
    private static let listExpression = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+]|([0-9]+)[.])([ \t]+)"#
    )

    public static func newlineEdit(in source: String, cursor: Int) -> MarkdownNewlineEdit? {
        let text = source as NSString
        guard cursor >= 0, cursor <= text.length else { return nil }

        var lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
        if lineRange.length > 0,
           text.character(at: NSMaxRange(lineRange) - 1) == 10
        {
            lineRange.length -= 1
        }
        let currentLine = text.substring(with: lineRange)
        guard let match = listExpression.firstMatch(
                in: currentLine,
                range: NSRange(location: 0, length: (currentLine as NSString).length)
        ) else { return nil }

        let markerRange = match.range(at: 2)
        let marker = (currentLine as NSString).substring(with: markerRange)
        let separator = (currentLine as NSString).substring(with: match.range(at: 4))
        let content = (currentLine as NSString).substring(from: NSMaxRange(match.range(at: 0)))
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            return MarkdownNewlineEdit(
                range: NSRange(location: lineRange.location, length: lineRange.length),
                replacement: "\n"
            )
        }

        let continuationMarker: String
        let numberRange = match.range(at: 3)
        if numberRange.location != NSNotFound,
           let number = Int((currentLine as NSString).substring(with: numberRange))
        {
            let nextNumber = String(number + 1)
            let width = numberRange.length
            continuationMarker = String(repeating: "0", count: max(0, width - nextNumber.utf16.count)) + nextNumber + "."
        } else {
            continuationMarker = marker
        }
        let indent = (currentLine as NSString).substring(with: match.range(at: 1))
        return MarkdownNewlineEdit(
            range: NSRange(location: cursor, length: 0),
            replacement: "\n\(indent)\(continuationMarker)\(separator)"
        )
    }
}
