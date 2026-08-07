import Foundation
import XCTest
@testable import TildeCore
@testable import TildeDocument
@testable import TildeMarkdown

@MainActor
final class MarkdownPreviewModelTests: XCTestCase {
    func testDangerousLinkIsRemovedFromPreparedMarkdown() async throws {
        let model = MarkdownPreviewModel()
        await model.render(snapshot: snapshot("[unsafe](javascript:alert(1))"))

        let prepared = try XCTUnwrap(model.prepared)
        XCTAssertFalse(prepared.attributedString.runs.contains { $0.link != nil })
    }

    func testSourceBudgetStopsRender() async {
        let model = MarkdownPreviewModel()
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = 3

        await model.render(snapshot: snapshot("1234"), policy: policy)

        XCTAssertNil(model.prepared)
        XCTAssertNotNil(model.errorMessage)
    }

    func testSourceBudgetUsesSnapshotByteCount() async {
        let model = MarkdownPreviewModel()
        var policy = MarkdownPolicy.default
        policy.maximumSourceBytes = 3
        let value = DocumentSnapshot(
            text: "x",
            revision: 1,
            encoding: .newDocumentUTF8,
            lineEnding: .lf,
            documentType: TildeDocumentType.markdown,
            fileURL: nil,
            utf8ByteCount: 4
        )

        await model.render(snapshot: value, policy: policy)

        XCTAssertNil(model.prepared)
        XCTAssertNotNil(model.errorMessage)
    }

    func testOutputBudgetStopsRender() async {
        let model = MarkdownPreviewModel()
        var policy = MarkdownPolicy.default
        policy.maximumOutputBytes = 3

        await model.render(snapshot: snapshot("1234"), policy: policy)

        XCTAssertNil(model.prepared)
        XCTAssertNotNil(model.errorMessage)
    }

    func testPreparedRevisionIsReusedForSameSnapshot() async throws {
        let model = MarkdownPreviewModel()
        let value = snapshot("# Cached", revision: 7)
        await model.render(snapshot: value)
        let first = try XCTUnwrap(model.prepared)

        await model.render(snapshot: value)

        XCTAssertEqual(model.prepared?.revision, first.revision)
        XCTAssertNil(model.errorMessage)
    }

    private func snapshot(_ text: String, revision: UInt64 = 1) -> DocumentSnapshot {
        DocumentSnapshot(
            text: text,
            revision: revision,
            encoding: .newDocumentUTF8,
            lineEnding: .lf,
            documentType: TildeDocumentType.markdown,
            fileURL: nil
        )
    }
}
