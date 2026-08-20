import Foundation

/// Encodes Mermaid source into an opaque, local-only URL used by the in-app attachment loader.
public enum MermaidSourceCodec {
    private static let scheme = "mermaid"

    public static func url(for source: String) -> URL? {
        let data = Data(source.utf8)
        let payload = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "\(scheme):\(payload)")
    }

    public static func source(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let encoded = String(url.absoluteString.dropFirst(scheme.count + 1))
        guard !encoded.isEmpty else { return nil }

        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Makes Markdown features that Foundation does not expose as structured attributes visible
/// to Textual while leaving fenced code blocks untouched.
public enum MarkdownSourcePreprocessor {
    public static func prepareForAttributedString(_ source: String) -> String {
        return replaceMermaidFences(in: source)
    }

    private static func replaceMermaidFences(in source: String) -> String {
        let lines = LineEndingDetector.normalize(source).text.components(separatedBy: "\n")
        var output: [String] = []
        var index = 0
        var listContexts: [ListContext] = []

        while index < lines.count {
            let line = lines[index]
            let listItem = listItemInfo(in: line)
            let isNestedList = listItem.map {
                isNestedListItem($0, in: listContexts)
            } ?? false

            if isIndentedCodeLine(line), !isNestedList {
                output.append(line)
                index += 1
                continue
            }

            guard let fence = Fence(line: line) else {
                output.append(normalizeTaskMarker(in: line))
                updateListContexts(
                    for: line,
                    listItem: listItem,
                    contexts: &listContexts
                )
                index += 1
                continue
            }

            guard fence.language == "mermaid" else {
                output.append(lines[index])
                index += 1
                while index < lines.count {
                    let bodyLine = lines[index]
                    output.append(bodyLine)
                    index += 1
                    if fence.closes(bodyLine) { break }
                }
                continue
            }

            let openingLine = lines[index]
            index += 1
            var body: [String] = []
            var rawBody: [String] = []
            var closed = false
            while index < lines.count, !fence.closes(lines[index]) {
                if fence.blockQuoteDepth > 0,
                   fence.depth(of: lines[index]) < fence.blockQuoteDepth
                {
                    break
                }
                rawBody.append(lines[index])
                body.append(fence.bodyLine(lines[index]))
                index += 1
            }
            if index < lines.count, fence.closes(lines[index]) {
                index += 1
                closed = true
            }

            guard closed else {
                output.append(openingLine)
                output.append(contentsOf: rawBody)
                continue
            }

            guard let url = MermaidSourceCodec.url(for: body.joined(separator: "\n")) else {
                output.append("```mermaid")
                output.append(contentsOf: body)
                output.append("```")
                continue
            }
            output.append(fence.blockQuotePrefix + "![Mermaid diagram](\(url.absoluteString))")
            if index < lines.count,
               !lines[index].trimmingCharacters(in: .whitespaces).isEmpty
            {
                output.append(fence.blockQuoteDepth > 0 ? fence.blockQuotePrefix : "")
            }
        }

        return output.joined(separator: "\n")
    }

    private static func normalizeTaskMarker(in line: String) -> String {
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor].isWhitespace {
            cursor = line.index(after: cursor)
        }

        if cursor < line.endIndex, line[cursor] == ">" {
            cursor = line.index(after: cursor)
            while cursor < line.endIndex, line[cursor].isWhitespace {
                cursor = line.index(after: cursor)
            }
        }

        guard cursor < line.endIndex else { return line }
        if "-*+".contains(line[cursor]) {
            cursor = line.index(after: cursor)
            guard cursor < line.endIndex, line[cursor].isWhitespace else { return line }
        } else {
            let digitsStart = cursor
            while cursor < line.endIndex, line[cursor].isNumber {
                cursor = line.index(after: cursor)
            }
            guard cursor > digitsStart,
                  cursor < line.endIndex,
                  line[cursor] == "." || line[cursor] == ")"
            else { return line }
            cursor = line.index(after: cursor)
            guard cursor < line.endIndex, line[cursor].isWhitespace else { return line }
        }

        while cursor < line.endIndex, line[cursor].isWhitespace {
            cursor = line.index(after: cursor)
        }
        guard line.distance(from: cursor, to: line.endIndex) >= 5,
              line[cursor] == "["
        else { return line }

        let marker = line.index(after: cursor)
        let closing = line.index(marker, offsetBy: 1)
        guard line[marker] == " " || line[marker] == "x" || line[marker] == "X",
              line[closing] == "]"
        else { return line }

        let afterClosing = line.index(after: closing)
        guard afterClosing < line.endIndex, line[afterClosing].isWhitespace else { return line }
        let checkbox = (line[marker] == "x" || line[marker] == "X") ? "☑" : "☐"
        return String(line[..<cursor]) + checkbox + String(line[afterClosing...])
    }

    private static func isIndentedCodeLine(_ line: String) -> Bool {
        var cursor = line.startIndex
        var spaces = 0
        while cursor < line.endIndex, line[cursor] == " " {
            spaces += 1
            cursor = line.index(after: cursor)
        }
        if spaces >= 4 || (cursor < line.endIndex && line[cursor] == "\t") {
            return true
        }

        guard cursor < line.endIndex, line[cursor] == ">" else { return false }
        repeat {
            cursor = line.index(after: cursor)
            if cursor < line.endIndex, line[cursor] == " " {
                cursor = line.index(after: cursor)
            }
            if cursor < line.endIndex, line[cursor] == "\t" {
                return true
            }

            spaces = 0
            while cursor < line.endIndex, line[cursor] == " " {
                spaces += 1
                cursor = line.index(after: cursor)
            }
            if spaces >= 4 {
                return true
            }
        } while cursor < line.endIndex && line[cursor] == ">"

        return false
    }

    private static func isNestedListItem(
        _ item: ListItemInfo,
        in contexts: [ListContext]
    ) -> Bool {
        contexts.contains { context in
            item.markerIndentation > context.markerIndentation
                && item.markerIndentation >= context.contentIndentation
                && item.markerIndentation < context.contentIndentation + 4
        }
    }

    private static func updateListContexts(
        for line: String,
        listItem: ListItemInfo?,
        contexts: inout [ListContext]
    ) {
        if let listItem {
            contexts.removeAll { $0.markerIndentation >= listItem.markerIndentation }
            contexts.append(
                ListContext(
                    markerIndentation: listItem.markerIndentation,
                    contentIndentation: listItem.contentIndentation
                )
            )
            return
        }

        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let indentation = line.prefix { $0 == " " }.count
        contexts.removeAll { indentation < $0.contentIndentation }
    }

    private static func listItemInfo(in line: String) -> ListItemInfo? {
        var cursor = line.startIndex
        var indentation = 0
        while cursor < line.endIndex, line[cursor] == " " {
            indentation += 1
            cursor = line.index(after: cursor)
        }
        guard cursor < line.endIndex else { return nil }

        let markerStart = cursor
        if "-*+".contains(line[cursor]) {
            cursor = line.index(after: cursor)
        } else {
            let digitsStart = cursor
            while cursor < line.endIndex, line[cursor].isNumber {
                cursor = line.index(after: cursor)
            }
            guard cursor > digitsStart,
                  cursor < line.endIndex,
                  line[cursor] == "." || line[cursor] == ")"
            else { return nil }
            cursor = line.index(after: cursor)
        }

        let markerWidth = line.distance(from: markerStart, to: cursor)
        let whitespaceStart = cursor
        while cursor < line.endIndex, line[cursor] == " " {
            cursor = line.index(after: cursor)
        }
        guard cursor > whitespaceStart else { return nil }

        let whitespaceWidth = line.distance(from: whitespaceStart, to: cursor)
        return ListItemInfo(
            markerIndentation: indentation,
            contentIndentation: indentation + markerWidth + min(whitespaceWidth, 4)
        )
    }
}

private struct ListContext {
    let markerIndentation: Int
    let contentIndentation: Int
}

private struct ListItemInfo {
    let markerIndentation: Int
    let contentIndentation: Int
}

private struct Fence {
    let character: Character
    let length: Int
    let language: String?
    let blockQuoteDepth: Int
    let blockQuotePrefix: String

    init?(line: String) {
        let parsed = Self.blockQuoteContent(from: line)
        let trimmed = parsed.content.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let run = trimmed.prefix { $0 == first }
        guard run.count >= 3 else { return nil }
        let info = trimmed.dropFirst(run.count).trimmingCharacters(in: .whitespaces)
        self.character = first
        self.length = run.count
        self.language = info.split(whereSeparator: { $0.isWhitespace }).first?.lowercased()
        self.blockQuoteDepth = parsed.depth
        self.blockQuotePrefix = parsed.prefix
    }

    func closes(_ line: String) -> Bool {
        let parsed = Self.blockQuoteContent(from: line)
        guard parsed.depth >= self.blockQuoteDepth else { return false }
        let trimmed = parsed.content.trimmingCharacters(in: .whitespaces)
        let run = trimmed.prefix { $0 == character }
        return run.count >= length && trimmed.dropFirst(run.count).trimmingCharacters(in: .whitespaces).isEmpty
    }

    func bodyLine(_ line: String) -> String {
        let parsed = Self.blockQuoteContent(from: line)
        guard parsed.depth >= self.blockQuoteDepth else { return line }
        return parsed.content
    }

    func depth(of line: String) -> Int {
        Self.blockQuoteContent(from: line).depth
    }

    private static func blockQuoteContent(from line: String) -> (
        content: String,
        depth: Int,
        prefix: String
    ) {
        var cursor = line.startIndex
        var spaces = 0
        while cursor < line.endIndex, line[cursor] == " ", spaces < 4 {
            cursor = line.index(after: cursor)
            spaces += 1
        }
        guard spaces <= 3,
              cursor < line.endIndex,
              line[cursor] == ">"
        else {
            return (line, 0, "")
        }

        var depth = 0
        while cursor < line.endIndex, line[cursor] == ">" {
            depth += 1
            cursor = line.index(after: cursor)
            while cursor < line.endIndex, line[cursor] == " " {
                cursor = line.index(after: cursor)
            }
            guard cursor < line.endIndex, line[cursor] == ">" else { break }
        }
        return (
            String(line[cursor...]),
            depth,
            String(line[..<cursor])
        )
    }
}
