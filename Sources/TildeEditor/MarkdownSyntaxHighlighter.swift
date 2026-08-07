import AppKit
import Foundation
import TildeCore

enum MarkdownSyntaxKind: Equatable, Sendable {
    case heading
    case marker
    case code
    case strong
    case emphasis
    case link
}

struct MarkdownSyntaxToken: Equatable, Sendable {
    let range: NSRange
    let kind: MarkdownSyntaxKind
}

@MainActor
enum MarkdownSyntaxTokenizer {
    private struct Pattern {
        let expression: NSRegularExpression
        let kind: MarkdownSyntaxKind

        init(_ pattern: String, kind: MarkdownSyntaxKind) {
            expression = try! NSRegularExpression(pattern: pattern)
            self.kind = kind
        }
    }

    private static let patterns: [Pattern] = [
        Pattern(#"(?m)^#{1,6}[ \t]+[^\n]*"#, kind: .heading),
        Pattern(#"(?m)^[ \t]*(?:`{3,}|~{3,})[^\n]*"#, kind: .code),
        Pattern(#"(?m)^[ \t]*(?:>[ \t]?|[-+*][ \t]+|\d+\.[ \t]+)"#, kind: .marker),
        Pattern(#"`{1,2}[^`\n]+`{1,2}"#, kind: .code),
        Pattern(#"(\*\*|__)(?=\S)[^\n]+?(?<=\S)\1"#, kind: .strong),
        Pattern(#"(?<!\*)\*(?=\S)[^*\n]+?(?<=\S)\*(?!\*)"#, kind: .emphasis),
        Pattern(#"!?\[[^\]\n]+\]\([^)\n]+\)"#, kind: .link),
    ]

    static func tokens(in text: String) -> [MarkdownSyntaxToken] {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return patterns.flatMap { pattern in
            pattern.expression.matches(in: text, range: range).map {
                MarkdownSyntaxToken(range: $0.range, kind: pattern.kind)
            }
        }
    }
}

@MainActor
final class MarkdownSyntaxHighlighter {
    private weak var layoutManager: NSLayoutManager?
    private weak var textStorage: NSTextStorage?

    init(layoutManager: NSLayoutManager, textStorage: NSTextStorage) {
        self.layoutManager = layoutManager
        self.textStorage = textStorage
    }

    func highlightAll() {
        guard let textStorage else { return }
        refresh(NSRange(location: 0, length: textStorage.length))
    }

    func highlight(edit: TextEdit) {
        guard let textStorage else { return }
        let text = textStorage.mutableString
        guard text.length > 0 else {
            clearAll()
            return
        }

        let replacementLength = edit.replacement.utf16.count
        let start = min(max(0, edit.range.location - 1), text.length)
        let proposedEnd = edit.range.location + replacementLength + 1
        let end = min(max(start, proposedEnd), text.length)
        let paragraphRange = text.paragraphRange(
            for: NSRange(location: start, length: end - start)
        )
        refresh(paragraphRange)
    }

    func clearAll() {
        guard let layoutManager, let textStorage, textStorage.length > 0 else { return }
        layoutManager.removeTemporaryAttribute(
            .foregroundColor,
            forCharacterRange: NSRange(location: 0, length: textStorage.length)
        )
    }

    private func refresh(_ requestedRange: NSRange) {
        guard let layoutManager, let textStorage else { return }
        let safeRange = NSIntersectionRange(
            requestedRange,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.location != NSNotFound else { return }

        if safeRange.length > 0 {
            layoutManager.removeTemporaryAttribute(
                .foregroundColor,
                forCharacterRange: safeRange
            )
        }
        guard safeRange.length > 0 else { return }

        let fragment = textStorage.mutableString.substring(with: safeRange)
        for token in MarkdownSyntaxTokenizer.tokens(in: fragment) {
            let globalRange = NSRange(
                location: safeRange.location + token.range.location,
                length: token.range.length
            )
            layoutManager.addTemporaryAttribute(
                .foregroundColor,
                value: color(for: token.kind),
                forCharacterRange: globalRange
            )
        }
    }

    private func color(for kind: MarkdownSyntaxKind) -> NSColor {
        switch kind {
        case .heading: .systemPurple
        case .marker: .secondaryLabelColor
        case .code: .systemOrange
        case .strong: .systemPink
        case .emphasis: .systemTeal
        case .link: .systemBlue
        }
    }
}
