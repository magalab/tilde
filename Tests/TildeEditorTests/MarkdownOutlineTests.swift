import XCTest
@testable import TildeEditor

final class MarkdownOutlineTests: XCTestCase {
    func testParsesHeadingLevelsAndLines() {
        let headings = MarkdownOutlineParser.headings(in: "# Title\n\n  ## Section ##\ntext\n### 中文")

        XCTAssertEqual(headings.map(\.level), [1, 2, 3])
        XCTAssertEqual(headings.map(\.title), ["Title", "Section", "中文"])
        XCTAssertEqual(headings.map(\.line), [1, 3, 5])
    }

    func testIgnoresInvalidAndEmptyHeadings() {
        let headings = MarkdownOutlineParser.headings(in: "####### too deep\n#\nnot a heading\n# Valid")

        XCTAssertEqual(headings.map(\.title), ["Valid"])
        XCTAssertEqual(headings.first?.range, NSRange(location: 33, length: 7))
    }

    func testSlugNormalizesPunctuationWhitespaceAndCase() {
        XCTAssertEqual(MarkdownOutlineParser.slug(for: "  Hello, World!  "), "hello-world")
        XCTAssertEqual(MarkdownOutlineParser.slug(for: "Build--Release"), "build-release")
    }
}
