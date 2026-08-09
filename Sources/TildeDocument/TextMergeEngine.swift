import Foundation

public struct TextMergeResult: Equatable, Sendable {
    public let text: String
    public let hasConflicts: Bool

    public init(text: String, hasConflicts: Bool) {
        self.text = text
        self.hasConflicts = hasConflicts
    }
}

public enum TextMergeEngine {
    public static func merge(base: String, local: String, external: String) -> TextMergeResult {
        guard local != base, external != base, local != external else {
            return TextMergeResult(
                text: local == base ? external : local,
                hasConflicts: false
            )
        }

        let baseLines = split(base)
        let localLines = split(local)
        let externalLines = split(external)
        let lineCount = max(baseLines.lines.count, localLines.lines.count, externalLines.lines.count)
        var merged: [String] = []
        var hasConflicts = false

        for index in 0..<lineCount {
            let baseLine = baseLines.lines[safe: index]
            let localLine = localLines.lines[safe: index]
            let externalLine = externalLines.lines[safe: index]

            if localLine == externalLine {
                if let localLine { merged.append(localLine) }
            } else if localLine == baseLine {
                if let externalLine { merged.append(externalLine) }
            } else if externalLine == baseLine {
                if let localLine { merged.append(localLine) }
            } else {
                hasConflicts = true
                merged.append("<<<<<<< LOCAL")
                if let localLine { merged.append(localLine) }
                merged.append("=======")
                if let externalLine { merged.append(externalLine) }
                merged.append(">>>>>>> DISK")
            }
        }

        let trailingNewline = localLines.hasTrailingNewline || externalLines.hasTrailingNewline
        return TextMergeResult(
            text: merged.joined(separator: "\n") + (trailingNewline ? "\n" : ""),
            hasConflicts: hasConflicts
        )
    }

    private static func split(_ text: String) -> (lines: [String], hasTrailingNewline: Bool) {
        let hasTrailingNewline = text.hasSuffix("\n")
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if hasTrailingNewline { lines.removeLast() }
        return (lines, hasTrailingNewline)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
