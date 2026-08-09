import Foundation
import XCTest
@testable import TildeCore
@testable import TildeDocument

@MainActor
final class TextDocumentTests: XCTestCase {
    func testDocumentOwnsDecodedTextAndPreservesUnchangedBytes() throws {
        let source = Data([0xEF, 0xBB, 0xBF]) + Data("hello\r\n".utf8)
        let document = TextDocument()

        try document.read(from: source, ofType: TildeDocumentType.plainText)

        XCTAssertEqual(document.textStorage.string, "hello\n")
        XCTAssertEqual(document.metadata.encoding.bomPolicy, .present)
        XCTAssertEqual(document.metadata.lineEndings.kind, .uniform(.crlf))
        XCTAssertEqual(document.metadata.sourceByteCount, source.count)
        XCTAssertEqual(document.workingUTF8ByteCount, Data("hello\n".utf8).count)
        XCTAssertEqual(document.markdownPreviewAvailability, .notMarkdown)
        XCTAssertEqual(try document.data(ofType: TildeDocumentType.plainText), source)
    }

    func testEditedUniformDocumentUsesOriginalLineEnding() throws {
        let source = Data("a\r\nb\r\n".utf8)
        let document = TextDocument()
        try document.read(from: source, ofType: TildeDocumentType.plainText)

        document.textStorage.append(NSAttributedString(string: "c\n"))
        document.noteTextChange()

        let output = try document.data(ofType: TildeDocumentType.plainText)
        XCTAssertEqual(String(decoding: output, as: UTF8.self), "a\r\nb\r\nc\r\n")
    }

    func testEditedMixedDocumentRequiresExplicitLineEnding() throws {
        let document = TextDocument()
        try document.read(
            from: Data("a\r\nb\nc\r".utf8),
            ofType: TildeDocumentType.plainText
        )
        document.textStorage.append(NSAttributedString(string: "d"))
        document.noteTextChange()

        XCTAssertThrowsError(try document.data(ofType: TildeDocumentType.plainText)) { error in
            XCTAssertEqual(error as? TextCodecError, .mixedLineEndingsRequireSelection)
        }

        document.changeLineEnding(to: .lf)
        XCTAssertEqual(
            String(decoding: try document.data(ofType: TildeDocumentType.plainText), as: UTF8.self),
            "a\nb\nc\nd"
        )
    }

    func testSnapshotCapturesRevisionAndMetadata() throws {
        let document = TextDocument()
        document.textStorage.append(NSAttributedString(string: "hello"))
        document.noteTextChange()

        let snapshot = document.makeSnapshot()
        XCTAssertEqual(snapshot.text, "hello")
        XCTAssertEqual(snapshot.revision, 1)
        XCTAssertEqual(snapshot.encoding, .newDocumentUTF8)
        XCTAssertEqual(snapshot.lineEnding, .lf)
        XCTAssertEqual(snapshot.utf8ByteCount, 5)
    }

    func testIncrementalEditTracksUTF8BytesWithoutRecountingDocument() throws {
        let document = TextDocument()
        try document.read(
            from: Data("a🐈b".utf8),
            ofType: TildeDocumentType.plainText
        )
        let catRange = (document.textStorage.string as NSString).range(of: "🐈")
        document.textStorage.replaceCharacters(in: catRange, with: "你")
        document.noteTextChange(TextEdit(
            range: catRange,
            replacement: "你",
            removedUTF8Length: 4
        ))

        XCTAssertEqual(document.workingUTF8ByteCount, Data("a你b".utf8).count)
        XCTAssertEqual(document.makeSnapshot().utf8ByteCount, Data("a你b".utf8).count)
    }

    func testOpenByteLimitRejectsAboveMeasuredMaximumWithoutAllocatingFile() {
        let policy = LargeFilePolicy.measuredBaseline

        XCTAssertNoThrow(try TextDocument.validateOpenByteCount(
            policy.maximumValidatedEditorBytes
        ))
        XCTAssertThrowsError(try TextDocument.validateOpenByteCount(
            policy.maximumValidatedEditorBytes + 1
        )) { error in
            XCTAssertEqual(
                error as? TextDocumentError,
                .fileExceedsValidatedLimit(
                    actualBytes: policy.maximumValidatedEditorBytes + 1,
                    maximumBytes: policy.maximumValidatedEditorBytes
                )
            )
        }
    }

    func testCleanExternalChangeReloadsDocumentAndAdvancesRevision() async throws {
        let fixture = try TemporaryTextFile(contents: Data("before\n".utf8))
        defer { fixture.remove() }
        let document = try makeDocument(reading: fixture.url)
        let originalRevision = document.revision

        try Data("after\n".utf8).write(to: fixture.url, options: .atomic)
        await document.refreshExternalFileState()

        XCTAssertEqual(document.textStorage.string, "after\n")
        XCTAssertGreaterThan(document.revision, originalRevision)
        XCTAssertEqual(document.externalChangeState, .unchanged)
    }

    func testDirtyExternalChangeKeepsLocalTextAndMarksConflict() async throws {
        let fixture = try TemporaryTextFile(contents: Data("disk\n".utf8))
        defer { fixture.remove() }
        let document = try makeDocument(reading: fixture.url)
        document.textStorage.append(NSAttributedString(string: "local\n"))
        document.noteTextChange()

        try Data("external\n".utf8).write(to: fixture.url, options: .atomic)
        await document.refreshExternalFileState()

        XCTAssertEqual(document.textStorage.string, "disk\nlocal\n")
        XCTAssertEqual(document.externalChangeState, .conflict)
    }

    func testExternalMergeUsesLoadedBaselineAndLeavesDocumentDirty() throws {
        let fixture = try TemporaryTextFile(contents: Data("one\ntwo\n".utf8))
        defer { fixture.remove() }
        let document = try makeDocument(reading: fixture.url)
        document.textStorage.replaceCharacters(
            in: NSRange(location: 4, length: 3),
            with: "local"
        )
        document.noteTextChange()

        let result = document.externalMergeResult(with: "one\ndisk\n")
        XCTAssertTrue(result.hasConflicts)
        document.applyExternalMerge(result)
        XCTAssertEqual(document.textStorage.string, result.text)
        XCTAssertTrue(document.isDocumentEdited)
        XCTAssertEqual(document.externalChangeState, .unchanged)
    }

    func testDeletedExternalFileKeepsTextAndRequiresRecovery() async throws {
        let fixture = try TemporaryTextFile(contents: Data("keep me".utf8))
        defer { fixture.remove() }
        let document = try makeDocument(reading: fixture.url)

        try FileManager.default.removeItem(at: fixture.url)
        await document.refreshExternalFileState()

        XCTAssertEqual(document.textStorage.string, "keep me")
        XCTAssertEqual(document.externalChangeState, .deletedOnDisk)
        XCTAssertTrue(document.isDocumentEdited)
    }

    func testReadOnlyExternalFileIsDetectedWithoutChangingText() async throws {
        let fixture = try TemporaryTextFile(contents: Data("read only".utf8))
        defer { fixture.remove() }
        let document = try makeDocument(reading: fixture.url)

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o444))],
            ofItemAtPath: fixture.url.path
        )
        await document.refreshExternalFileState()

        XCTAssertEqual(document.textStorage.string, "read only")
        XCTAssertEqual(document.externalChangeState, .becameReadOnly)
    }

    func testExplicitEncodingOpenHandlesAmbiguousBOMlessUTF16() throws {
        let utf16LEChinese = Data([0x60, 0x4F, 0x7D, 0x59])
        let fixture = try TemporaryTextFile(contents: utf16LEChinese)
        defer { fixture.remove() }
        let controller = TextDocumentController()

        let document = try controller.openDocument(
            at: fixture.url,
            using: .utf16LittleEndian,
            display: false
        )
        defer { controller.removeDocument(document) }

        XCTAssertEqual(document.textStorage.string, "你好")
        XCTAssertEqual(document.metadata.encoding.encoding, .utf16LittleEndian)
        XCTAssertEqual(try document.data(ofType: TildeDocumentType.plainText), utf16LEChinese)
    }

    func testSuccessfulSafeSaveWritesCurrentSnapshot() async throws {
        let fixture = try TemporaryTextFile(contents: Data())
        defer { fixture.remove() }
        let target = fixture.directory.appendingPathComponent("saved.txt")
        let document = TextDocument()
        document.fileType = TildeDocumentType.plainText
        document.textStorage.append(NSAttributedString(string: "saved\n"))
        document.noteTextChange()
        let finished = expectation(description: "safe save")
        nonisolated(unsafe) var saveError: Error?

        document.save(
            to: target,
            ofType: TildeDocumentType.plainText,
            for: .saveAsOperation
        ) { error in
            saveError = error
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)

        XCTAssertNil(saveError)
        XCTAssertEqual(try Data(contentsOf: target), Data("saved\n".utf8))
        XCTAssertFalse(document.isDocumentEdited)
    }

    func testSaveAsMarkdownUpdatesPreviewAvailability() async throws {
        let fixture = try TemporaryTextFile(contents: Data())
        defer { fixture.remove() }
        let target = fixture.directory.appendingPathComponent("saved.md")
        let document = TextDocument()
        document.fileType = TildeDocumentType.plainText
        document.textStorage.append(NSAttributedString(string: "# Markdown\n"))
        document.noteTextChange()
        let finished = expectation(description: "save as Markdown")
        nonisolated(unsafe) var saveError: Error?

        document.save(
            to: target,
            ofType: TildeDocumentType.markdown,
            for: .saveAsOperation
        ) { error in
            saveError = error
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)

        XCTAssertNil(saveError)
        XCTAssertEqual(document.metadata.documentType, TildeDocumentType.markdown)
        XCTAssertEqual(document.markdownPreviewAvailability, .available)
    }

    private func makeDocument(reading url: URL) throws -> TextDocument {
        let document = TextDocument()
        document.fileURL = url
        document.fileType = TildeDocumentType.plainText
        try document.read(
            from: Data(contentsOf: url),
            ofType: TildeDocumentType.plainText
        )
        document.updateChangeCount(.changeCleared)
        return document
    }
}

private final class TemporaryTextFile: @unchecked Sendable {
    let directory: URL
    let url: URL

    init(contents: Data) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TildeDocumentTests-\(UUID().uuidString)", isDirectory: true)
        url = directory.appendingPathComponent("fixture.txt")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try contents.write(to: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
