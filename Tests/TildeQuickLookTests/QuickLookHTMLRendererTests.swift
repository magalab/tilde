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

