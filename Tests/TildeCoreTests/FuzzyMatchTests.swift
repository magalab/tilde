import XCTest
@testable import TildeCore

final class FuzzyMatchTests: XCTestCase {
    func testMatchesSubsequence() {
        XCTAssertNotNil(FuzzyMatcher.match(query: "mdpv", in: "MarkdownPreviewView.swift"))
    }

    func testRejectsMissingCharacter() {
        XCTAssertNil(FuzzyMatcher.match(query: "xyz", in: "MarkdownPreviewView.swift"))
    }

    func testFilenameMatchScoresAboveDeepPathMatch() throws {
        let filename = try XCTUnwrap(FuzzyMatcher.match(query: "mdpv", in: "MarkdownPreviewView.swift"))
        let path = try XCTUnwrap(FuzzyMatcher.match(query: "mdpv", in: "Sources/legacy/markdown_preview_view.swift"))
        XCTAssertGreaterThan(filename.score, path.score)
    }
}
