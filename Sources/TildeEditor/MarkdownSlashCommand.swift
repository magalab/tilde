import Foundation
import TildeCore

public enum MarkdownSlashCommand: String, CaseIterable, Identifiable, Sendable {
    case heading1 = "h1"
    case heading2 = "h2"
    case heading3 = "h3"
    case bullet
    case number
    case todo
    case quote
    case code

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .heading1: L10n.string("Heading 1")
        case .heading2: L10n.string("Heading 2")
        case .heading3: L10n.string("Heading 3")
        case .bullet: L10n.string("Bullet List")
        case .number: L10n.string("Numbered List")
        case .todo: L10n.string("Task List")
        case .quote: L10n.string("Quote")
        case .code: L10n.string("Code Block")
        }
    }

    var replacement: String {
        switch self {
        case .heading1: "# "
        case .heading2: "## "
        case .heading3: "### "
        case .bullet: "- "
        case .number: "1. "
        case .todo: "- [ ] "
        case .quote: "> "
        case .code: "```\n\n```"
        }
    }
}

public enum MarkdownSlashCommandTransformer {
    public static func edit(
        in source: String,
        cursor: Int,
        command: MarkdownSlashCommand
    ) -> TextEdit? {
        let value = source as NSString
        guard cursor > 0, cursor <= value.length else { return nil }
        let lineRange = value.lineRange(for: NSRange(location: cursor - 1, length: 0))
        let line = value.substring(with: lineRange)
        let contentEnd = line.hasSuffix("\n") ? line.index(before: line.endIndex) : line.endIndex
        let lineWithoutNewline = String(line[..<contentEnd])
        let leadingWhitespace = lineWithoutNewline.prefix { $0 == " " || $0 == "\t" }
        let prefix = String(leadingWhitespace)
        guard lineWithoutNewline.dropFirst(prefix.count).hasPrefix("/") else { return nil }
        guard !isInsideCodeFence(in: source, before: lineRange.location) else { return nil }

        let slashLocation = lineRange.location + prefix.utf16.count
        let typedCommand = lineWithoutNewline.dropFirst(prefix.count + 1)
        guard typedCommand.isEmpty || command.rawValue.hasPrefix(typedCommand.lowercased()) else { return nil }

        let replacement = command.replacement
        let replacementRange = NSRange(
            location: slashLocation,
            length: max(1, lineWithoutNewline.utf16.count - prefix.utf16.count)
        )
        return TextEdit(range: replacementRange, replacement: replacement)
    }

    public static func canTrigger(in source: String, cursor: Int) -> Bool {
        let value = source as NSString
        // NSString.character(at:) returns a UTF-16 code unit; 0x2F is '/'.
        guard cursor > 0, cursor <= value.length, value.character(at: cursor - 1) == 0x2F else { return false }
        let lineRange = value.lineRange(for: NSRange(location: cursor - 1, length: 0))
        let line = value.substring(with: lineRange)
        let prefix = line.prefix { $0 == " " || $0 == "\t" }
        let slashLocation = lineRange.location + String(prefix).utf16.count
        guard cursor == slashLocation + 1,
              line.dropFirst(prefix.count).first == "/"
        else { return false }
        return !isInsideCodeFence(in: source, before: lineRange.location)
    }

    private static func isInsideCodeFence(in source: String, before location: Int) -> Bool {
        let prefix = (source as NSString).substring(with: NSRange(location: 0, length: min(location, (source as NSString).length)))
        return prefix.split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(into: false) { inside, line in
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { inside.toggle() }
            }
    }
}
