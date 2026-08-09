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
    case quote
    case deletion
    case html
    case image
    case url
    case table
    case frontMatter
    case language
    case codeKeyword
    case codeString
    case codeComment
    case codeNumber
    case codeType
    case codeProperty
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
        Pattern(#"(?ms)\A---\n.*?\n---(?:\n|$)"#, kind: .frontMatter),
        Pattern(#"(?m)^#{1,6}[ \t]+[^\n]*"#, kind: .heading),
        Pattern(#"(?m)^[ \t]*(?:`{3,}|~{3,})[ \t]*[A-Za-z0-9_+.-]+[^\n]*"#, kind: .language),
        Pattern(#"(?ms)^[ \t]*(?:`{3,}|~{3,})[^\n]*\n.*?^[ \t]*(?:`{3,}|~{3,})[ \t]*(?:\n|$)"#, kind: .code),
        Pattern(#"(?m)^[ \t]*(?:>[ \t]?|[-+*][ \t]+|\d+\.[ \t]+)"#, kind: .marker),
        Pattern(#"(?m)^[ \t]*>[^\n]*"#, kind: .quote),
        Pattern(#"(?m)^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*(?:\|[^\n]*)?$"#, kind: .table),
        Pattern(#"`{1,2}[^`\n]+`{1,2}"#, kind: .code),
        Pattern(#"(\*\*|__)(?=\S)[^\n]+?(?<=\S)\1"#, kind: .strong),
        Pattern(#"(?<!\*)\*(?=\S)[^*\n]+?(?<=\S)\*(?!\*)"#, kind: .emphasis),
        Pattern(#"(~~)(?=\S)[^\n]+?(?<=\S)\1"#, kind: .deletion),
        Pattern(#"!\[[^\]\n]*\]\([^\)\n]+\)"#, kind: .image),
        Pattern(#"!?\[[^\]\n]+\]\([^)\n]+\)"#, kind: .link),
        Pattern(#"(?<![\w])(https?://[^\s<>()]+|www\.[^\s<>()]+)"#, kind: .url),
        Pattern(#"</?[A-Za-z][^>\n]*>"#, kind: .html),
    ]

    private static let fencedCodeExpression = try! NSRegularExpression(
        pattern: #"(?ms)^[ \t]*(`{3,}|~{3,})[ \t]*([A-Za-z0-9_+.-]+)[^\n]*\n(.*?)^[ \t]*\1[ \t]*(?:\n|$)"#
    )

    private struct LanguageDefinition {
        let keywords: String
        let comment: String
        let supportsTypes: Bool
        let supportsProperties: Bool
    }

    private static let languages: [String: LanguageDefinition] = [
        "swift": .init(
            keywords: #"actor|any|associatedtype|async|await|class|convenience|defer|enum|extension|func|guard|if|import|in|init|let|macro|nil|operator|private|protocol|public|return|self|static|struct|switch|throws|try|var|where|while"#,
            comment: #"//[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "objc": .init(
            keywords: #"auto|bool|class|const|else|for|if|import|interface|nil|return|static|struct|typedef|void|while"#,
            comment: #"//[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "c": .init(
            keywords: #"auto|break|case|char|const|continue|default|do|else|enum|for|if|include|int|long|return|short|signed|static|struct|typedef|unsigned|void|while"#,
            comment: #"//[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "cpp": .init(
            keywords: #"alignas|auto|bool|break|case|catch|class|const|continue|default|delete|else|enum|for|if|include|int|namespace|new|nullptr|private|public|return|static|struct|template|this|throw|try|using|virtual|void|while"#,
            comment: #"//[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "javascript": .init(
            keywords: #"async|await|break|case|catch|class|const|continue|debugger|default|delete|else|export|extends|finally|for|from|function|if|import|in|instanceof|let|new|null|of|return|static|super|switch|this|throw|try|typeof|undefined|var|void|while|with|yield"#,
            comment: #"//[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "typescript": .init(
            keywords: #"as|async|await|break|case|catch|class|const|continue|declare|default|else|enum|export|extends|finally|for|from|function|if|implements|import|in|interface|is|keyof|let|namespace|new|null|of|private|public|readonly|return|static|switch|this|throw|try|type|typeof|undefined|var|void|while|with|yield"#,
            comment: #"//[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "json": .init(
            keywords: #"true|false|null"#,
            comment: #"(?!)"#,
            supportsTypes: false,
            supportsProperties: true
        ),
        "python": .init(
            keywords: #"and|as|assert|async|await|break|case|class|continue|def|del|elif|else|except|False|finally|for|from|global|if|import|in|is|lambda|match|None|not|or|pass|raise|return|True|try|while|with|yield"#,
            comment: #"#[^\n]*"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "shell": .init(
            keywords: #"case|do|done|elif|else|esac|export|fi|for|function|if|in|local|return|then|until|while"#,
            comment: #"#[^\n]*"#,
            supportsTypes: false,
            supportsProperties: false
        ),
        "sql": .init(
            keywords: #"alter|and|as|begin|case|create|delete|drop|else|end|from|group|having|insert|into|join|limit|not|null|on|or|order|select|set|table|then|union|update|values|when|where|with"#,
            comment: #"--[^\n]*|/\*[\s\S]*?\*/"#,
            supportsTypes: false,
            supportsProperties: false
        ),
        "html": .init(
            keywords: #"!DOCTYPE|DOCTYPE"#,
            comment: #"<!--[\s\S]*?-->"#,
            supportsTypes: true,
            supportsProperties: false
        ),
        "css": .init(
            keywords: #"@media|@supports|@import|important"#,
            comment: #"/\*[\s\S]*?\*/"#,
            supportsTypes: false,
            supportsProperties: true
        ),
        "yaml": .init(
            keywords: #"true|false|null|yes|no"#,
            comment: #"#[^\n]*"#,
            supportsTypes: false,
            supportsProperties: true
        )
    ]

    private static let aliases: [String: String] = [
        "js": "javascript", "jsx": "javascript", "mjs": "javascript",
        "ts": "typescript", "tsx": "typescript",
        "objc": "objc", "objective-c": "objc", "c++": "cpp", "h": "c", "hpp": "cpp",
        "py": "python", "sh": "shell", "bash": "shell", "zsh": "shell",
        "yml": "yaml", "htm": "html"
    ]

    static func tokens(in text: String) -> [MarkdownSyntaxToken] {
        let range = NSRange(location: 0, length: (text as NSString).length)
        var result = patterns.flatMap { pattern in
            pattern.expression.matches(in: text, range: range).map {
                MarkdownSyntaxToken(range: $0.range, kind: pattern.kind)
            }
        }
        result.append(contentsOf: languageTokens(in: text, range: range))
        return result
    }

    private static func languageTokens(in text: String, range: NSRange) -> [MarkdownSyntaxToken] {
        var result: [MarkdownSyntaxToken] = []
        for match in fencedCodeExpression.matches(in: text, range: range) {
            let languageRange = match.range(at: 2)
            let bodyRange = match.range(at: 3)
            let rawLanguage = (text as NSString).substring(with: languageRange).lowercased()
            let language = aliases[rawLanguage] ?? rawLanguage
            guard let definition = languages[language] else { continue }
            let body = (text as NSString).substring(with: bodyRange)
            result.append(contentsOf: lexicalTokens(
                in: body,
                baseLocation: bodyRange.location,
                definition: definition
            ))
        }
        return result
    }

    private static func lexicalTokens(
        in text: String,
        baseLocation: Int,
        definition: LanguageDefinition
    ) -> [MarkdownSyntaxToken] {
        let nsRange = NSRange(location: 0, length: (text as NSString).length)
        let patterns: [(String, MarkdownSyntaxKind, Int)] = [
            (definition.comment, .codeComment, 100),
            (#"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, .codeString, 90),
            (#"\b\d+(?:\.\d+)?\b"#, .codeNumber, 50),
            (#"\b(?:"# + definition.keywords + #")\b"#, .codeKeyword, 70)
        ] + (definition.supportsTypes ? [(#"\b[A-Z][A-Za-z0-9_]*\b"#, .codeType, 60)] : [])
            + (definition.supportsProperties ? [(#"\"[^\"\n]+\"(?=\s*:)|\b[A-Za-z_][A-Za-z0-9_-]*(?=\s*:)"#, .codeProperty, 95)] : [])

        struct Candidate {
            let token: MarkdownSyntaxToken
            let priority: Int
        }
        let candidates = patterns.flatMap { pattern, kind, priority in
            (try? NSRegularExpression(pattern: pattern)).map { expression in
                expression.matches(in: text, range: nsRange).map { match in
                    Candidate(
                        token: MarkdownSyntaxToken(
                            range: NSRange(
                                location: baseLocation + match.range.location,
                                length: match.range.length
                            ),
                            kind: kind
                        ),
                        priority: priority
                    )
                }
            } ?? []
        }
        var selected: [Candidate] = []
        for candidate in candidates.sorted(by: {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.token.range.location < $1.token.range.location
        }) where candidate.token.range.length > 0 {
            guard selected.allSatisfy({ NSIntersectionRange($0.token.range, candidate.token.range).length == 0 }) else {
                continue
            }
            selected.append(candidate)
        }
        return selected
            .sorted { $0.token.range.location < $1.token.range.location }
            .map(\.token)
    }
}

@MainActor
final class MarkdownSyntaxHighlighter {
    private weak var layoutManager: NSLayoutManager?
    private weak var textStorage: NSTextStorage?
    private let palette: EditorThemePalette

    init(
        layoutManager: NSLayoutManager,
        textStorage: NSTextStorage,
        palette: EditorThemePalette = .light
    ) {
        self.layoutManager = layoutManager
        self.textStorage = textStorage
        self.palette = palette
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
        case .heading: palette.heading.nsColor
        case .marker: palette.marker.nsColor
        case .code: palette.code.nsColor
        case .strong: palette.strong.nsColor
        case .emphasis: palette.emphasis.nsColor
        case .link: palette.link.nsColor
        case .quote: palette.quote.nsColor
        case .deletion: palette.deletion.nsColor
        case .html: palette.html.nsColor
        case .image: palette.link.nsColor
        case .url: palette.link.nsColor
        case .table: palette.marker.nsColor
        case .frontMatter: palette.html.nsColor
        case .language: palette.code.nsColor
        case .codeKeyword: palette.emphasis.nsColor
        case .codeString: palette.code.nsColor
        case .codeComment: palette.quote.nsColor
        case .codeNumber: palette.marker.nsColor
        case .codeType: palette.heading.nsColor
        case .codeProperty: palette.link.nsColor
        }
    }
}
