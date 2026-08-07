import XCTest
@testable import TildeCore

final class LargeFilePolicyTests: XCTestCase {
    private let policy = LargeFilePolicy.measuredBaseline

    func testMeasuredEditorBoundaries() {
        XCTAssertEqual(
            policy.disposition(forByteCount: policy.largeFileThresholdBytes - 1),
            .standard
        )
        XCTAssertEqual(
            policy.disposition(forByteCount: policy.largeFileThresholdBytes),
            .largeFileMode
        )
        XCTAssertEqual(
            policy.disposition(forByteCount: policy.maximumValidatedEditorBytes),
            .largeFileMode
        )
        XCTAssertEqual(
            policy.disposition(forByteCount: policy.maximumValidatedEditorBytes + 1),
            .exceedsValidatedLimit
        )
    }

    func testMarkdownPreviewCeiling() {
        XCTAssertTrue(policy.allowsMarkdownPreview(
            utf8ByteCount: policy.maximumMarkdownPreviewBytes
        ))
        XCTAssertFalse(policy.allowsMarkdownPreview(
            utf8ByteCount: policy.maximumMarkdownPreviewBytes + 1
        ))
    }
}
