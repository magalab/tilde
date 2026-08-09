import Foundation
import XCTest
@testable import TildeCore

final class MarkdownPolicyTests: XCTestCase {
    func testDangerousLinkSchemesAreRejected() {
        let policy = MarkdownPolicy.default
        XCTAssertFalse(policy.allowsLink("javascript:alert(1)"))
        XCTAssertFalse(policy.allowsLink("file:///etc/passwd"))
        XCTAssertTrue(policy.allowsLink("https://example.com"))
        XCTAssertTrue(policy.allowsLink("mailto:hello@example.com"))
        XCTAssertTrue(policy.allowsLink("relative/path.md"))
    }

    func testRemoteResourcesAreDisabledByDefault() {
        let policy = MarkdownPolicy.default
        XCTAssertFalse(policy.allowsRemoteResource(URL(string: "https://example.com/image.png")!))
        XCTAssertTrue(policy.allowsRemoteResource(URL(fileURLWithPath: "/tmp/image.png")))

        var enabled = policy
        enabled.allowsRemoteResources = true
        XCTAssertTrue(enabled.allowsRemoteResource(URL(string: "https://example.com/image.png")!))
    }

    func testResourceResolverRejectsTraversalAndRemoteURLs() {
        let base = URL(fileURLWithPath: "/tmp/tilde-doc")
        XCTAssertNil(MarkdownResourceResolver.localResourceURL(
            for: URL(string: "https://example.com/tracker.png")!,
            documentDirectory: base
        ))
        XCTAssertNil(MarkdownResourceResolver.localResourceURL(
            for: URL(string: "../secret.png")!,
            documentDirectory: base
        ))
        XCTAssertEqual(
            MarkdownResourceResolver.localResourceURL(
                for: URL(string: "images/local.png")!,
                documentDirectory: base
            )?.path,
            "/tmp/tilde-doc/images/local.png"
        )
    }

    func testHTMLEscaping() {
        XCTAssertEqual(
            HTMLEscaping.escape("<script a='\"'>&"),
            "&lt;script a=&#39;&quot;&#39;&gt;&amp;"
        )
    }
}
