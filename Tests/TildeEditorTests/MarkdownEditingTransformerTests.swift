import Foundation
import XCTest
@testable import TildeEditor

final class MarkdownEditingTransformerTests: XCTestCase {
    func testContinuesBulletList() throws {
        let source = "- first"
        let edit = try XCTUnwrap(
            MarkdownEditingTransformer.newlineEdit(in: source, cursor: (source as NSString).length)
        )
        XCTAssertEqual(edit.range, NSRange(location: source.utf16.count, length: 0))
        XCTAssertEqual(edit.replacement, "\n- ")
    }

    func testIncrementsOrderedList() throws {
        let source = "  01.\tthird"
        let edit = try XCTUnwrap(
            MarkdownEditingTransformer.newlineEdit(in: source, cursor: (source as NSString).length)
        )
        XCTAssertEqual(edit.replacement, "\n  02.\t")
    }

    func testEmptyBulletExitsList() throws {
        let source = "- "
        let edit = try XCTUnwrap(
            MarkdownEditingTransformer.newlineEdit(in: source, cursor: (source as NSString).length)
        )
        XCTAssertEqual(edit.range, NSRange(location: 0, length: source.utf16.count))
        XCTAssertEqual(edit.replacement, "\n")
    }

    func testSplitsListWhenCursorIsBeforeContent() throws {
        let source = "- first"
        let edit = try XCTUnwrap(
            MarkdownEditingTransformer.newlineEdit(in: source, cursor: 2)
        )
        XCTAssertEqual(edit.range, NSRange(location: 2, length: 0))
        XCTAssertEqual(edit.replacement, "\n- ")
    }

}
