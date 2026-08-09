import Foundation

public struct MarkdownHeading: Equatable, Identifiable, Sendable {
    public let id: Int
    public let level: Int
    public let title: String
    public let line: Int
    public let range: NSRange

    public init(id: Int, level: Int, title: String, line: Int, range: NSRange) {
        self.id = id
        self.level = level
        self.title = title
        self.line = line
        self.range = range
    }
}

public enum MarkdownOutlineParser {
    public static func slug(for title: String) -> String {
        let normalized = title
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
        var result = ""
        var needsSeparator = false
        for scalar in normalized.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if needsSeparator, !result.isEmpty { result.append("-") }
                result.append(contentsOf: String(scalar))
                needsSeparator = false
            } else if scalar == "-" || scalar == "_" || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                needsSeparator = true
            }
        }
        return result
    }

    public static func headings(in source: String) -> [MarkdownHeading] {
        let value = source as NSString
        var headings: [MarkdownHeading] = []
        var lineStart = 0
        var lineNumber = 1

        while lineStart <= value.length {
            let remaining = NSRange(location: lineStart, length: value.length - lineStart)
            let newline = value.range(of: "\n", options: [], range: remaining)
            let lineEnd = newline.location == NSNotFound ? value.length : newline.location
            let line = value.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
            let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
            let content = line.dropFirst(leadingWhitespace.count)
            let hashes = content.prefix { $0 == "#" }
            let level = hashes.count

            if (1...6).contains(level), content.dropFirst(level).first == " " || content.dropFirst(level).first == "\t" {
                let rawTitle = content.dropFirst(level)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let title = rawTitle.replacingOccurrences(
                    of: #"[ \t]+#+[ \t]*$"#,
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    headings.append(MarkdownHeading(
                        id: headings.count,
                        level: level,
                        title: title,
                        line: lineNumber,
                        range: NSRange(location: lineStart, length: lineEnd - lineStart)
                    ))
                }
            }

            guard newline.location != NSNotFound else { break }
            lineStart = newline.location + newline.length
            lineNumber += 1
        }

        return headings
    }
}
