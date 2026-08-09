import XCTest
@testable import TildeDocument

final class TextMergeEngineTests: XCTestCase {
    func testUnchangedSideIsAcceptedAutomatically() {
        let result = TextMergeEngine.merge(
            base: "one\ntwo\n",
            local: "one\nlocal\n",
            external: "one\ntwo\nexternal\n"
        )
        XCTAssertFalse(result.hasConflicts)
        XCTAssertEqual(result.text, "one\nlocal\nexternal\n")
    }

    func testConflictingLineProducesMarkers() {
        let result = TextMergeEngine.merge(
            base: "one\ntwo\n",
            local: "one\nlocal\n",
            external: "one\ndisk\n"
        )
        XCTAssertTrue(result.hasConflicts)
        XCTAssertEqual(
            result.text,
            "one\n<<<<<<< LOCAL\nlocal\n=======\ndisk\n>>>>>>> DISK\n"
        )
    }

    func testIdenticalOrUnchangedDocumentsDoNotCreateConflictMarkers() {
        XCTAssertEqual(
            TextMergeEngine.merge(base: "text", local: "text", external: "disk"),
            TextMergeResult(text: "disk", hasConflicts: false)
        )
        XCTAssertEqual(
            TextMergeEngine.merge(base: "text", local: "same", external: "same"),
            TextMergeResult(text: "same", hasConflicts: false)
        )
    }
}
