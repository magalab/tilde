import Foundation
import XCTest
@testable import TildeCore

final class MarkdownSourcePreprocessorTests: XCTestCase {
    func testNormalizesTaskListMarkersOutsideFencedCode() {
        let source = "- [x] done\n- [ ] todo\n\n```text\n- [x] keep source\n```"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertEqual(
            prepared,
            "- ☑ done\n- ☐ todo\n\n```text\n- [x] keep source\n```"
        )
        XCTAssertTrue(prepared.contains("- [x] keep source"))
    }

    func testNormalizesTaskListMarkerInsideBlockquote() {
        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString("> - [x] done")

        XCTAssertEqual(prepared, "> - ☑ done")
    }

    func testLeavesIndentedCodeTaskMarkerUntouched() {
        let source = "    - [x] this is code\n    - [ ] more code"

        XCTAssertEqual(
            MarkdownSourcePreprocessor.prepareForAttributedString(source),
            source
        )
    }

    func testNormalizesNestedTaskListWithFourSpaceIndentation() {
        let source = "- parent\n    - [x] nested task"

        XCTAssertEqual(
            MarkdownSourcePreprocessor.prepareForAttributedString(source),
            "- parent\n    - ☑ nested task"
        )
    }

    func testLeavesIndentedCodeTaskMarkerInsideBlockquoteUntouched() {
        let source = ">     - [x] this is code"

        XCTAssertEqual(
            MarkdownSourcePreprocessor.prepareForAttributedString(source),
            source
        )
    }

    func testReplacesMermaidFenceWithOpaqueImageURL() throws {
        let source = "Before\n\n```mermaid\ngraph TD\nA-->B\n```\n\nAfter"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertFalse(prepared.contains("```mermaid"))
        let mermaidParts = prepared.split(separator: "mermaid:", maxSplits: 1)
        let encoded = try XCTUnwrap(mermaidParts.dropFirst().first)
            .split(separator: ")", maxSplits: 1)[0]
        let url = try XCTUnwrap(URL(string: "mermaid:\(encoded)"))
        XCTAssertEqual(MermaidSourceCodec.source(from: url), "graph TD\nA-->B")
    }

    func testReplacesBlockquoteMermaidFence() throws {
        let source = "> ```mermaid\n> graph TD\n> A-->B\n> ```\n> after"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertTrue(prepared.hasPrefix("> ![Mermaid diagram](mermaid:"))
        let encoded = prepared
            .split(separator: ":", maxSplits: 1)[1]
            .split(separator: ")", maxSplits: 1)[0]
        let url = try XCTUnwrap(URL(string: "mermaid:\(encoded)"))
        XCTAssertEqual(MermaidSourceCodec.source(from: url), "graph TD\nA-->B")
        XCTAssertTrue(prepared.contains("\n> \n> after"))
    }

    func testReplacesNestedBlockquoteMermaidFence() throws {
        let source = "> > ```mermaid\n> > graph TD\n> > A-->B\n> > ```"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertTrue(prepared.hasPrefix("> > ![Mermaid diagram](mermaid:"))
        let encoded = prepared
            .split(separator: ":", maxSplits: 1)[1]
            .split(separator: ")", maxSplits: 1)[0]
        let url = try XCTUnwrap(URL(string: "mermaid:\(encoded)"))
        XCTAssertEqual(MermaidSourceCodec.source(from: url), "graph TD\nA-->B")
    }

    func testNormalizesCRLFBeforeReplacingMermaidFence() throws {
        let source = "```mermaid\r\ngraph TD\r\nA-->B\r\n```\r\n"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        let encoded = prepared
            .split(separator: ":", maxSplits: 1)[1]
            .split(separator: ")", maxSplits: 1)[0]
        let url = try XCTUnwrap(URL(string: "mermaid:\(encoded)"))
        XCTAssertEqual(MermaidSourceCodec.source(from: url), "graph TD\nA-->B")
    }

    func testDoesNotConsumeUnquotedLineIntoBlockquoteMermaidFence() {
        let source = "> ```mermaid\n> graph TD\nA-->B\n> ```"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertFalse(prepared.contains("![Mermaid diagram]"))
        XCTAssertEqual(prepared, source)
    }

    func testLongerFenceKeepsShorterFenceInMermaidSource() throws {
        let source = "~~~~mermaid\n```\ngraph TD\nA-->B\n~~~~"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        let encoded = prepared
            .split(separator: ":", maxSplits: 1)[1]
            .split(separator: ")", maxSplits: 1)[0]
        let url = try XCTUnwrap(URL(string: "mermaid:\(encoded)"))
        XCTAssertEqual(MermaidSourceCodec.source(from: url), "```\ngraph TD\nA-->B")
    }

    func testLeavesNonMermaidFencedCodeUntouched() {
        let source = "```swift\nlet value = \"[x]\"\n```"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertEqual(prepared, source)
    }

    func testLeavesUnclosedMermaidFenceAsCode() {
        let source = "```mermaid\ngraph TD\nA-->B"

        let prepared = MarkdownSourcePreprocessor.prepareForAttributedString(source)

        XCTAssertEqual(prepared, source)
    }
}
