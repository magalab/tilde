import Foundation
import XCTest
@testable import TildeCore

final class LineIndexTests: XCTestCase {
    func testBuildsOffsetsAndUnicodeColumns() {
        let text = "first\n🐈éx\nlast"
        let index = LineIndex(text: text)

        XCTAssertEqual(index.lineCount, 3)
        XCTAssertEqual(index.offset(forLine: 1), 0)
        XCTAssertEqual(index.offset(forLine: 2), 6)
        XCTAssertEqual(index.offset(forLine: 3), 12)
        XCTAssertEqual(index.position(forUTF16Offset: 11, in: text), TextPosition(line: 2, column: 4))
    }

    func testInsertionUpdatesFollowingLines() {
        var index = LineIndex(text: "a\nb")
        index.apply(TextEdit(range: NSRange(location: 1, length: 0), replacement: "x\ny"))

        XCTAssertEqual(index.lineCount, 3)
        XCTAssertEqual(index.offset(forLine: 2), 3)
        XCTAssertEqual(index.offset(forLine: 3), 5)
        XCTAssertEqual(index.utf16Length, 6)
    }

    func testReplacingNewlineRemovesLineBoundary() {
        var index = LineIndex(text: "a\nb\nc")
        index.apply(TextEdit(range: NSRange(location: 1, length: 1), replacement: " "))

        XCTAssertEqual(index.lineCount, 2)
        XCTAssertEqual(index.offset(forLine: 2), 4)
    }

    func testReplacingRangeAtNextLineStartKeepsBoundary() {
        var index = LineIndex(text: "a\nb")
        index.apply(TextEdit(range: NSRange(location: 2, length: 1), replacement: "bee"))

        XCTAssertEqual(index.lineCount, 2)
        XCTAssertEqual(index.offset(forLine: 2), 2)
        XCTAssertEqual(index.utf16Length, 5)
    }

    func testEditsAcrossBlockBoundaryWithoutChangingLaterOffsetsIncorrectly() {
        let original = (1...1_100).map { "line-\($0)" }.joined(separator: "\n")
        var edited = original
        var index = LineIndex(text: original)

        let insertion = "new first line\n"
        edited = insertion + edited
        index.apply(TextEdit(range: NSRange(location: 0, length: 0), replacement: insertion))

        XCTAssertEqual(index.lineCount, 1_101)
        XCTAssertEqual(index.offset(forLine: 514), (edited as NSString).range(of: "line-513").location)
        XCTAssertEqual(index.offset(forLine: 1_101), (edited as NSString).range(of: "line-1100").location)
    }

    func testRemovingNewlineAtBlockBoundaryMergesLines() {
        let original = Array(repeating: "x", count: 520).joined(separator: "\n")
        var index = LineIndex(text: original)
        let boundaryOffset = index.offset(forLine: 513)!

        index.apply(TextEdit(
            range: NSRange(location: boundaryOffset - 1, length: 1),
            replacement: ""
        ))

        XCTAssertEqual(index.lineCount, 519)
        XCTAssertEqual(index.offset(forLine: 513), boundaryOffset + 1)
        XCTAssertEqual(index.offset(forLine: 519), original.utf16.count - 2)
    }

    func testNSStringPositionOverloadCountsGraphemeClusters() {
        let text: NSString = "🐈éx\n尾"
        let index = LineIndex(text: text as String)

        XCTAssertEqual(
            index.position(forUTF16Offset: 5, in: text),
            TextPosition(line: 1, column: 4)
        )
        XCTAssertEqual(
            index.position(forUTF16Offset: 6, in: text),
            TextPosition(line: 2, column: 1)
        )
    }
}
