import Foundation
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
