import AppKit
import XCTest
@testable import TildeCore
@testable import TildeEditor

@MainActor
final class MarkdownSyntaxHighlighterTests: XCTestCase {
    func testTokenizerRecognizesCommonMarkdownSyntax() {
        let source = """
        # Heading
        - **bold** and *emphasis* with `code`
        [link](https://example.com)
        """

        let kinds = Set(MarkdownSyntaxTokenizer.tokens(in: source).map(\.kind))

        XCTAssertTrue(kinds.contains(.heading))
        XCTAssertTrue(kinds.contains(.marker))
        XCTAssertTrue(kinds.contains(.strong))
        XCTAssertTrue(kinds.contains(.emphasis))
        XCTAssertTrue(kinds.contains(.code))
        XCTAssertTrue(kinds.contains(.link))
    }

    func testHighlightingUsesTemporaryAttributesOnly() throws {
        let storage = NSTextStorage(string: "# Heading\nplain")
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        let highlighter = MarkdownSyntaxHighlighter(
            layoutManager: layoutManager,
            textStorage: storage
        )

        highlighter.highlightAll()

        XCTAssertNil(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        XCTAssertNotNil(layoutManager.temporaryAttribute(
            .foregroundColor,
            atCharacterIndex: 0,
            effectiveRange: nil
        ))
        XCTAssertEqual(storage.string, "# Heading\nplain")

        highlighter.clearAll()
        XCTAssertNil(layoutManager.temporaryAttribute(
            .foregroundColor,
            atCharacterIndex: 0,
            effectiveRange: nil
        ))
    }

    func testIncrementalHighlightRemovesStaleHeadingColor() {
        let storage = NSTextStorage(string: "# Heading\nplain")
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        let highlighter = MarkdownSyntaxHighlighter(
            layoutManager: layoutManager,
            textStorage: storage
        )
        highlighter.highlightAll()

        storage.replaceCharacters(in: NSRange(location: 0, length: 1), with: "x")
        highlighter.highlight(edit: TextEdit(
            range: NSRange(location: 0, length: 1),
            replacement: "x",
            removedUTF8Length: 1
        ))

        XCTAssertNil(layoutManager.temporaryAttribute(
            .foregroundColor,
            atCharacterIndex: 0,
            effectiveRange: nil
        ))
    }
}
