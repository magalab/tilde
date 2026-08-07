import Foundation

public struct TextEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let removedUTF8Length: Int?

    public init(
        range: NSRange,
        replacement: String,
        removedUTF8Length: Int? = nil
    ) {
        self.range = range
        self.replacement = replacement
        self.removedUTF8Length = removedUTF8Length
    }
}

public struct TextPosition: Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public struct LineIndex: Equatable, Sendable {
    private static let maximumLinesPerBlock = 512

    private struct LineBlock: Equatable, Sendable {
        let lengths: [Int]
        let utf16Length: Int

        init(lengths: [Int]) {
            self.lengths = lengths
            utf16Length = lengths.reduce(0, +)
        }
    }

    private struct LocatedLine {
        let blockIndex: Int
        let localLineIndex: Int
        let globalLineIndex: Int
        let startOffset: Int
        let length: Int
    }

    private var blocks: [LineBlock]
    public private(set) var lineCount: Int
    public private(set) var utf16Length: Int

    public init(text: String = "") {
        let lengths = Self.makeLineLengths(text)
        blocks = Self.makeBlocks(from: lengths)
        lineCount = lengths.count
        utf16Length = text.utf16.count
    }

    public mutating func rebuild(for text: String) {
        let lengths = Self.makeLineLengths(text)
        blocks = Self.makeBlocks(from: lengths)
        lineCount = lengths.count
        utf16Length = text.utf16.count
    }

    public mutating func apply(_ edit: TextEdit) {
        let location = min(max(0, edit.range.location), utf16Length)
        let length = min(max(0, edit.range.length), utf16Length - location)
        let oldEnd = location + length
        let start = locateLine(containing: location)
        let end = locateLine(containing: oldEnd)

        let prefixLength = location - start.startOffset
        let suffixLength = end.length - (oldEnd - end.startOffset)
        var insertedLengths = Self.makeLineLengths(edit.replacement)
        insertedLengths[0] += prefixLength
        insertedLengths[insertedLengths.count - 1] += suffixLength

        var rebuiltLengths = Array(blocks[start.blockIndex].lengths[..<start.localLineIndex])
        rebuiltLengths.append(contentsOf: insertedLengths)
        let endBlockLengths = blocks[end.blockIndex].lengths
        let suffixStart = end.localLineIndex + 1
        if suffixStart < endBlockLengths.count {
            rebuiltLengths.append(contentsOf: endBlockLengths[suffixStart...])
        }

        blocks.replaceSubrange(
            start.blockIndex...end.blockIndex,
            with: Self.makeBlocks(from: rebuiltLengths)
        )

        let removedLineCount = end.globalLineIndex - start.globalLineIndex + 1
        lineCount += insertedLengths.count - removedLineCount
        utf16Length += edit.replacement.utf16.count - length
    }

    public func offset(forLine line: Int) -> Int? {
        guard line >= 1, line <= lineCount else { return nil }

        var remainingLineIndex = line - 1
        var offset = 0
        for block in blocks {
            if remainingLineIndex < block.lengths.count {
                return offset + block.lengths[..<remainingLineIndex].reduce(0, +)
            }
            remainingLineIndex -= block.lengths.count
            offset += block.utf16Length
        }
        return nil
    }

    public func position(forUTF16Offset offset: Int, in text: String) -> TextPosition {
        position(forUTF16Offset: offset, in: text as NSString)
    }

    public func position(forUTF16Offset offset: Int, in text: NSString) -> TextPosition {
        let clampedOffset = min(max(0, offset), utf16Length)
        let locatedLine = locateLine(containing: clampedOffset)
        let columnRange = NSRange(
            location: locatedLine.startOffset,
            length: clampedOffset - locatedLine.startOffset
        )
        let columnText = text.substring(with: columnRange)
        return TextPosition(
            line: locatedLine.globalLineIndex + 1,
            column: columnText.count + 1
        )
    }

    private func locateLine(containing offset: Int) -> LocatedLine {
        var blockStartOffset = 0
        var blockStartLine = 0

        for (blockIndex, block) in blocks.enumerated() {
            let blockEndOffset = blockStartOffset + block.utf16Length
            let isLastBlock = blockIndex == blocks.count - 1
            if offset < blockEndOffset || (isLastBlock && offset <= blockEndOffset) {
                var lineStartOffset = blockStartOffset
                for (localLineIndex, lineLength) in block.lengths.enumerated() {
                    let lineEndOffset = lineStartOffset + lineLength
                    let globalLineIndex = blockStartLine + localLineIndex
                    let isLastLine = globalLineIndex == lineCount - 1
                    if offset < lineEndOffset || (isLastLine && offset <= lineEndOffset) {
                        return LocatedLine(
                            blockIndex: blockIndex,
                            localLineIndex: localLineIndex,
                            globalLineIndex: globalLineIndex,
                            startOffset: lineStartOffset,
                            length: lineLength
                        )
                    }
                    lineStartOffset = lineEndOffset
                }
            }
            blockStartOffset = blockEndOffset
            blockStartLine += block.lengths.count
        }

        preconditionFailure("Line index must contain its UTF-16 end offset")
    }

    private static func makeLineLengths(_ text: String) -> [Int] {
        var lengths: [Int] = []
        var currentLength = 0
        for unit in text.utf16 {
            currentLength += 1
            if unit == 0x0A {
                lengths.append(currentLength)
                currentLength = 0
            }
        }
        lengths.append(currentLength)
        return lengths
    }

    private static func makeBlocks(from lengths: [Int]) -> [LineBlock] {
        precondition(!lengths.isEmpty)
        var result: [LineBlock] = []
        result.reserveCapacity((lengths.count + maximumLinesPerBlock - 1) / maximumLinesPerBlock)

        var start = 0
        while start < lengths.count {
            let end = min(start + maximumLinesPerBlock, lengths.count)
            result.append(LineBlock(lengths: Array(lengths[start..<end])))
            start = end
        }
        return result
    }
}
