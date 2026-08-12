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

    func testResetReleasesPreparedMarkdown() async throws {
        let model = MarkdownPreviewModel()
        await model.render(snapshot: snapshot("```swift\nlet value = 1\n```"))
        XCTAssertNotNil(model.prepared)

        model.reset()

        XCTAssertNil(model.prepared)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isRendering)
    }

    func testRenderingNewRevisionDoesNotRetainPreviousPreparedMarkdown() async throws {
        let model = MarkdownPreviewModel()
        await model.render(snapshot: snapshot("# First", revision: 1))
        XCTAssertNotNil(model.prepared)

        await model.render(snapshot: snapshot("# Second", revision: 2))

        let prepared = try XCTUnwrap(model.prepared)
        XCTAssertEqual(prepared.revision, 2)
        XCTAssertEqual(String(prepared.attributedString.characters), "Second")
    }

    func testStaleRenderCannotReplaceNewerPreparedMarkdownOrError() async throws {
        let controller = RenderController()
        let model = MarkdownPreviewModel { snapshot, _ in
            try await controller.prepare(snapshot: snapshot)
        }

        let firstRender = Task {
            await model.render(snapshot: snapshot("# First", revision: 1))
        }
        await controller.waitUntilStarted(revision: 1)

        model.reset()
        let secondRender = Task {
            await model.render(snapshot: snapshot("# Second", revision: 2))
        }
        await controller.waitUntilStarted(revision: 2)
        await controller.succeed(revision: 2, text: "Second")
        await secondRender.value

        await controller.fail(revision: 1)
        await firstRender.value

        let prepared = try XCTUnwrap(model.prepared)
        XCTAssertEqual(prepared.revision, 2)
        XCTAssertEqual(String(prepared.attributedString.characters), "Second")
        XCTAssertNil(model.errorMessage)
    }

    func testSourceLimitClearsRenderingStateWhilePreviousRenderIsInFlight() async {
        let controller = RenderController()
        let model = MarkdownPreviewModel { snapshot, _ in
            try await controller.prepare(snapshot: snapshot)
        }

        let firstRender = Task {
            await model.render(snapshot: snapshot("# First", revision: 1))
        }
        await controller.waitUntilStarted(revision: 1)
        XCTAssertTrue(model.isRendering)

        var limitedPolicy = MarkdownPolicy.default
        limitedPolicy.maximumSourceBytes = 1
        await model.render(
            snapshot: snapshot("# Second", revision: 2),
            policy: limitedPolicy
        )

        XCTAssertFalse(model.isRendering)
        XCTAssertNotNil(model.errorMessage)

        await controller.fail(revision: 1)
        await firstRender.value
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

private enum TestRenderError: Error {
    case failed
}

private actor RenderController {
    private var startedRevisions = Set<UInt64>()
    private var continuations: [UInt64: CheckedContinuation<PreparedMarkdown, Error>] = [:]

    func prepare(snapshot: DocumentSnapshot) async throws -> PreparedMarkdown {
        startedRevisions.insert(snapshot.revision)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[snapshot.revision] = continuation
        }
    }

    func waitUntilStarted(revision: UInt64) async {
        while !startedRevisions.contains(revision) {
            await Task.yield()
        }
    }

    func succeed(revision: UInt64, text: String) {
        guard let continuation = continuations.removeValue(forKey: revision) else { return }
        continuation.resume(
            returning: PreparedMarkdown(
                attributedString: AttributedString(text),
                revision: revision
            )
        )
    }

    func fail(revision: UInt64) {
        guard let continuation = continuations.removeValue(forKey: revision) else { return }
        continuation.resume(throwing: TestRenderError.failed)
    }
}
