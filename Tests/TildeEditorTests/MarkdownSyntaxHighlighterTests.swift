import AppKit
import XCTest
@testable import TildeCore
@testable import TildeEditor

@MainActor
final class MarkdownSyntaxHighlighterTests: XCTestCase {
    func testTokenizerRecognizesCommonMarkdownSyntax() {
        let source = """
        # Heading
        ---
        title: Example
        ---
        - **bold** and *emphasis* with `code`
        > quote and ~~deleted~~
        ```swift
        let value = 1
        ```
        [link](https://example.com)
        <span>html</span>
        ![image](image.png)
        | a | b |
        | --- | --- |
        https://example.com
        """

        let kinds = Set(MarkdownSyntaxTokenizer.tokens(in: source).map(\.kind))

        XCTAssertTrue(kinds.contains(.heading))
        XCTAssertTrue(kinds.contains(.marker))
        XCTAssertTrue(kinds.contains(.strong))
        XCTAssertTrue(kinds.contains(.emphasis))
        XCTAssertTrue(kinds.contains(.code))
        XCTAssertTrue(kinds.contains(.link))
        XCTAssertTrue(kinds.contains(.quote))
        XCTAssertTrue(kinds.contains(.deletion))
        XCTAssertTrue(kinds.contains(.html))
        XCTAssertTrue(kinds.contains(.image))
        XCTAssertTrue(kinds.contains(.table))
        XCTAssertTrue(kinds.contains(.url))
    }

    func testTokenizerHighlightsLanguageCodeBlockTokens() {
        let source = """
        ```swift
        // comment
        let title: String = \"Tilde\"
        let count = 42
        ```
        ```json
        {\"name\": true}
        ```
        """

        let kinds = Set(MarkdownSyntaxTokenizer.tokens(in: source).map(\.kind))
        XCTAssertTrue(kinds.contains(.codeComment))
        XCTAssertTrue(kinds.contains(.codeKeyword))
        XCTAssertTrue(kinds.contains(.codeString))
        XCTAssertTrue(kinds.contains(.codeNumber))
        XCTAssertTrue(kinds.contains(.codeType))
        XCTAssertTrue(kinds.contains(.codeProperty))
    }

    func testLanguageAliasesAndUnicodeKeepUTF16Ranges() throws {
        let source = "```js\nconst title = \"中文\"\n```"
        let tokens = MarkdownSyntaxTokenizer.tokens(in: source)
        let stringToken = try XCTUnwrap(tokens.first(where: { $0.kind == .codeString }))
        let expectedLocation = (source as NSString).range(of: "\"中文\"").location
        XCTAssertEqual(stringToken.range.location, expectedLocation)
        XCTAssertEqual(
            stringToken.range.length,
            ("\"中文\"" as NSString).length
        )
        XCTAssertTrue(tokens.contains { $0.kind == .codeKeyword })
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
