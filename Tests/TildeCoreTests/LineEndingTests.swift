import XCTest
@testable import TildeCore

final class LineEndingTests: XCTestCase {
    func testNormalizesEverySupportedLineEnding() {
        let result = LineEndingDetector.normalize("a\r\nb\rc\nd")

        XCTAssertEqual(result.text, "a\nb\nc\nd")
        XCTAssertEqual(result.profile, LineEndingProfile(lfCount: 1, crlfCount: 1, crCount: 1))
        XCTAssertEqual(result.profile.kind, .mixed)
    }

    func testNoLineEndings() {
        let result = LineEndingDetector.normalize("hello")
        XCTAssertEqual(result.profile.kind, .none)
        XCTAssertEqual(result.profile.dominant, .lf)
    }

    func testUniformLineEnding() {
        let result = LineEndingDetector.normalize("a\r\nb\r\n")
        XCTAssertEqual(result.profile.kind, .uniform(.crlf))
        XCTAssertEqual(result.profile.dominant, .crlf)
    }

    func testDominantLineEndingPrefersHighestCount() {
        let profile = LineEndingProfile(lfCount: 2, crlfCount: 5, crCount: 1)
        XCTAssertEqual(profile.dominant, .crlf)
    }

    func testEncodingNormalizedTextWithCRLF() throws {
        let data = try TextEncoder.encode(
            "a\nb\n",
            encoding: .newDocumentUTF8,
            lineEnding: .crlf
        )
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "a\r\nb\r\n")
    }
}

