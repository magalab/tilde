import Foundation

public struct IndentationEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }
}

public enum IndentationTransformer {
    public static func indent(
        text: String,
        selection: NSRange,
        style: IndentStyle,
        width: Int
    ) -> IndentationEdit? {
        let source = text as NSString
        guard let lineRange = selectedLineRange(in: source, selection: selection) else { return nil }
        let prefix = style == .tabs ? "\t" : String(repeating: " ", count: max(1, width))
        let original = source.substring(with: lineRange)
        var replacement = prefix + original.replacingOccurrences(of: "\n", with: "\n\(prefix)")
        if original.hasSuffix("\n") {
            replacement.removeLast(prefix.count)
        }
        return IndentationEdit(
            range: lineRange,
            replacement: replacement,
            selection: NSRange(location: lineRange.location, length: replacement.utf16.count)
        )
    }

    public static func outdent(
        text: String,
        selection: NSRange,
        width: Int
    ) -> IndentationEdit? {
        let source = text as NSString
        guard let lineRange = selectedLineRange(in: source, selection: selection) else { return nil }
        let original = source.substring(with: lineRange)
        let maximumSpaces = max(1, width)
        let lines = original.split(separator: "\n", omittingEmptySubsequences: false)
        var changed = false
        let transformed = lines.map { line -> Substring in
            if line.first == "\t" {
                changed = true
                return line.dropFirst()
            }
            let spaces = line.prefix(maximumSpaces).prefix { $0 == " " }.count
            if spaces > 0 {
                changed = true
                return line.dropFirst(spaces)
            }
            return line
        }
        guard changed else { return nil }
        let replacement = transformed.joined(separator: "\n")
        return IndentationEdit(
            range: lineRange,
            replacement: replacement,
            selection: NSRange(location: lineRange.location, length: replacement.utf16.count)
        )
    }

    private static func selectedLineRange(in text: NSString, selection: NSRange) -> NSRange? {
        guard selection.location != NSNotFound, selection.location <= text.length else { return nil }
        let availableLength = text.length - selection.location
        var clamped = NSRange(
            location: selection.location,
            length: min(selection.length, availableLength)
        )
        if clamped.length > 0,
           NSMaxRange(clamped) <= text.length,
           text.character(at: NSMaxRange(clamped) - 1) == 0x0A
        {
            clamped.length -= 1
        }
        return text.lineRange(for: clamped)
    }
}
