import Foundation
import XCTest
@testable import TildeEditor

final class IndentationTransformerTests: XCTestCase {
    func testIndentsSelectedLinesWithSpaces() throws {
        let edit = try XCTUnwrap(IndentationTransformer.indent(
            text: "one\ntwo\nthree",
            selection: NSRange(location: 0, length: 7),
            style: .spaces,
            width: 2
        ))
        XCTAssertEqual(edit.range, NSRange(location: 0, length: 8))
        XCTAssertEqual(edit.replacement, "  one\n  two\n")
    }

    func testSelectionEndingAfterNewlineDoesNotIndentFollowingLine() throws {
        let edit = try XCTUnwrap(IndentationTransformer.indent(
            text: "one\ntwo",
            selection: NSRange(location: 0, length: 4),
            style: .tabs,
            width: 4
        ))
        XCTAssertEqual(edit.replacement, "\tone\n")
    }

    func testOutdentRemovesTabOrUpToConfiguredSpaces() throws {
        let source = "\tone\n  two\nplain"
        let edit = try XCTUnwrap(IndentationTransformer.outdent(
            text: source,
            selection: NSRange(location: 0, length: (source as NSString).length),
            width: 4
        ))
        XCTAssertEqual(edit.replacement, "one\ntwo\nplain")
    }

    func testOutdentReturnsNilWhenNoLineIsIndented() {
        XCTAssertNil(IndentationTransformer.outdent(
            text: "one\ntwo",
            selection: NSRange(location: 0, length: 7),
            width: 4
        ))
    }

    func testUnicodeBeforeSelectionKeepsUTF16RangeCorrect() throws {
        let source = "😀\ntext"
        let edit = try XCTUnwrap(IndentationTransformer.indent(
            text: source,
            selection: NSRange(location: 3, length: 4),
            style: .spaces,
            width: 2
        ))
        XCTAssertEqual(edit.range, NSRange(location: 3, length: 4))
        XCTAssertEqual(edit.replacement, "  text")
    }
}
