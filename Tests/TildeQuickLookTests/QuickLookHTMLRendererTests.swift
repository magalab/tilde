import Foundation
import Markdown
import XCTest
@testable import TildeCore
@testable import TildeQuickLook

final class QuickLookHTMLRendererTests: XCTestCase {
    func testRendersCoreMarkdownAndTables() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "# Title\n\n| A | B |\n|---|---|\n| 1 | 2 |"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("Content-Security-Policy"))
    }

    func testRendersDisplayMathAndMatricesAsMathML() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "$$\n\\int_0^1 x^2 \\, dx = \\frac{1}{3}\n$$\n\n$$ A = \\begin{bmatrix} 1 & 2 \\\\ 3 & 4 \\end{bmatrix} $$"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("<math display=\"block\">"))
        XCTAssertTrue(html.contains("<mfrac>"))
        XCTAssertTrue(html.contains("<mtable>"))
        XCTAssertFalse(html.contains("$$"))
    }

    func testRendersInlineMathAsMathML() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "Euler's identity: $e^{i\\pi} + 1 = 0$."
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("<math>"))
        XCTAssertTrue(html.contains("<msup>"))
        XCTAssertFalse(html.contains("$e"))
    }

    func testKeepsDollarSignsInsideCodeBlock() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "```swift\nlet price = \"$1.99\"\n```"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("$1.99"))
        XCTAssertFalse(html.contains("<math>"))
    }

    func testDoesNotInterpretCurrencyAsInlineMath() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "Price $1.99, $.50, or $2,50; **$3.99** or [sale $4.99](https://example.com)."
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("$1.99"))
        XCTAssertTrue(html.contains("$.50"))
        XCTAssertTrue(html.contains("$2,50"))
        XCTAssertTrue(html.contains("$3.99"))
        XCTAssertTrue(html.contains("$4.99"))
        XCTAssertFalse(html.contains("<math>"))
    }

    func testUnclosedDisplayMathFallsBackToLiteralText() throws {
        let rendered = try QuickLookHTMLRenderer.render(markdown: "$$abc")
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("$$abc"))
        XCTAssertFalse(html.contains("<math display=\"block\">"))
    }

    func testUnclosedDisplayMathOverflowsAccumulatorSafely() throws {
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = 2
        let document = Document([
            Paragraph([Text("$$"), Text("a"), Text("bc")])
        ])
        let rendered = try QuickLookHTMLRenderer.render(document: document, policy: policy)
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertFalse(html.contains("<math"))
        XCTAssertTrue(html.contains("$$abc"))
    }

    func testNestedMatrixFallsBackSafely() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "$$\\begin{bmatrix} \\begin{bmatrix} 1 & 2 \\\\ 3 & 4 \\end{bmatrix} \\end{bmatrix}$$"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("<math display=\"block\">"))
        XCTAssertTrue(html.contains("<mtable>"))
        XCTAssertTrue(html.contains("<mtr>"))
        XCTAssertTrue(html.contains("<mtd>"))
        XCTAssertTrue(html.contains("<mfenced"))
        XCTAssertFalse(html.contains("$$"))
    }

    func testLongMathBlockClosesAcrossTextNodes() throws {
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = 3
        let document = Document([
            Paragraph([Text("$$"), Text("abdef$$")])
        ])
        let rendered = try QuickLookHTMLRenderer.render(document: document, policy: policy)
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("<math display=\"block\">"))
        XCTAssertFalse(html.contains("$$abdef"))
    }

    func testOverflowResumesNormalMathParsing() throws {
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = 3
        let document = Document([
            Paragraph([Text("$$"), Text("ab"), Text("def"), Text("$$c$$")])
        ])
        let rendered = try QuickLookHTMLRenderer.render(document: document, policy: policy)
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("$$ab"))
        XCTAssertTrue(html.contains("<math display=\"block\">"))
        XCTAssertFalse(html.contains("$$c$$"))
    }

    func testKeepsTaskCheckboxInsideListParagraph() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "- [x] done\n- [ ] todo"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("<li><p><input type=\"checkbox\" disabled checked> done</p>"))
        XCTAssertTrue(html.contains("<li><p><input type=\"checkbox\" disabled> todo</p>"))
    }

    func testEmitsTaskCheckboxForEmptyParagraphNode() throws {
        let document = Document([
            UnorderedList([
                ListItem(checkbox: .checked, Paragraph([])),
                ListItem(checkbox: .unchecked, Paragraph([])),
            ])
        ])
        let rendered = try QuickLookHTMLRenderer.render(document: document)
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 2)
    }

    func testEmitsTaskCheckboxBeforeCodeBlock() throws {
        let document = Document([
            UnorderedList([
                ListItem(
                    checkbox: .checked,
                    CodeBlock(language: "python", "print(1)")
                )
            ])
        ])
        let rendered = try QuickLookHTMLRenderer.render(document: document)
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 1)
        XCTAssertTrue(html.contains("<span class=\"task-marker\"><input type=\"checkbox\" disabled checked></span>"))
        XCTAssertTrue(html.contains("<pre><code class=\"language-python\">"))
        XCTAssertTrue(html.contains("print(1)"))
    }

    func testEmitsOnlyOneTaskCheckboxForMultipleParagraphs() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "- [x] first\n\n  second"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 1)
        XCTAssertTrue(html.contains("<p><input type=\"checkbox\" disabled checked> first</p>"))
        XCTAssertTrue(html.contains("<p>second</p>"))
        XCTAssertFalse(html.contains("<p><input type=\"checkbox\" disabled checked> second"))
        XCTAssertTrue(html.contains("first"))
        XCTAssertTrue(html.contains("second"))
    }

    func testRendersMermaidAsPNGAttachment() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "```mermaid\ngraph TD\nA-->B\n```"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertEqual(rendered.attachments.count, 1)
        XCTAssertEqual(rendered.attachments[0].contentTypeIdentifier, "public.png")
        XCTAssertTrue(html.contains("src=\"cid:mermaid-0\""))
        XCTAssertFalse(html.contains("language-mermaid"))
    }

    func testUnrenderableMermaidFallsBackToCodeBlock() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "```mermaid\nnot a supported diagram\n```"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(rendered.attachments.isEmpty)
        XCTAssertTrue(html.contains("language-mermaid"))
        XCTAssertTrue(html.contains("not a supported diagram"))
    }

    func testMermaidDiagramCountBudgetFallsBackAfterLimit() throws {
        var policy = MarkdownPolicy.default
        policy.maximumMermaidDiagramCount = 1
        let markdown = "```mermaid\ngraph TD\nA-->B\n```\n\n```mermaid\ngraph TD\nB-->C\n```"

        let rendered = try QuickLookHTMLRenderer.render(markdown: markdown, policy: policy)
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertEqual(rendered.attachments.count, 1)
        XCTAssertTrue(html.contains("cid:mermaid-0"))
        XCTAssertTrue(html.contains("language-mermaid"))
    }

    func testRendersTaskListCheckboxes() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "- [x] done\n- [ ] todo"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(html.contains("disabled checked"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled>"))
        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 2)
        XCTAssertEqual(html.components(separatedBy: "disabled checked").count - 1, 1)
    }

    func testEscapesRawHTMLAndBlocksDangerousLinks() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "<script>alert('x')</script>\n\n[bad](javascript:alert(1))"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertFalse(html.contains("href=\"javascript:"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertTrue(html.contains(">bad<"))
    }

    func testRemoteImagesAreNotLoaded() throws {
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "![tracker](https://example.com/tracker.png)"
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertTrue(rendered.attachments.isEmpty)
        XCTAssertTrue(html.contains("[Image: tracker]"))
        XCTAssertFalse(html.contains("https://example.com/tracker.png"))
    }

    func testLocalImageBecomesCIDAttachment() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let imageURL = directory.appendingPathComponent("pixel.png")
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        try png.write(to: imageURL)
        let documentURL = directory.appendingPathComponent("README.md")

        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "![pixel](pixel.png)",
            documentURL: documentURL
        )
        let html = String(decoding: rendered.data, as: UTF8.self)

        XCTAssertEqual(rendered.attachments.count, 1)
        XCTAssertEqual(rendered.attachments[0].data, png)
        XCTAssertTrue(html.contains("src=\"cid:asset-0\""))
    }

    func testPathTraversalImageIsBlocked() throws {
        let directory = URL(fileURLWithPath: "/tmp/safe/document", isDirectory: true)
        let rendered = try QuickLookHTMLRenderer.render(
            markdown: "![secret](../../etc/passwd)",
            documentURL: directory.appendingPathComponent("README.md")
        )

        XCTAssertTrue(rendered.attachments.isEmpty)
    }

    func testSourceLimitReturnsError() {
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = 4
        XCTAssertThrowsError(
            try QuickLookHTMLRenderer.render(markdown: "12345", policy: policy)
        ) { error in
            XCTAssertEqual(error as? QuickLookRenderError, .sourceTooLarge)
        }
    }
}
