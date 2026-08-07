import AppKit
import Combine
import Foundation
import TildeCore

@MainActor
public final class TextDocument: NSDocument, @preconcurrency ObservableObject {
    public typealias WindowControllerFactory = @MainActor (TextDocument) -> NSWindowController

    public static var windowControllerFactory: WindowControllerFactory?

    public let objectWillChange = ObservableObjectPublisher()
    public let textStorage: NSTextStorage
    public private(set) var metadata: DocumentMetadata
    public private(set) var revision: UInt64 = 0
    public private(set) var externalChangeState: ExternalChangeState = .unchanged
    public private(set) var lineIndex: LineIndex
    public private(set) var workingUTF8ByteCount: Int = 0

    private var loadedRevision: UInt64 = 0
    private var originalData: Data?
    private var metadataHasChanged = false
    private var isHandlingExternalChange = false
    private var pendingWrittenBaseline: SavedBaseline?

    public override init() {
        textStorage = NSTextStorage()
        metadata = DocumentMetadata()
        lineIndex = LineIndex()
        super.init()
    }

    public override class var autosavesInPlace: Bool { true }
    public override class var preservesVersions: Bool { true }
    public override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    public func configureNewDocument(metadata: DocumentMetadata) {
        guard fileURL == nil, textStorage.length == 0, revision == 0 else { return }
        objectWillChange.send()
        self.metadata = metadata
    }

    public override func makeWindowControllers() {
        if let factory = Self.windowControllerFactory {
            addWindowController(factory(self))
            return
        }

        let viewController = NSViewController()
        let label = NSTextField(
            labelWithString: L10n.string("Tilde document UI has not been configured.")
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        viewController.view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
        viewController.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
        ])
        let window = NSWindow(contentViewController: viewController)
        window.setContentSize(NSSize(width: 720, height: 520))
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
        addWindowController(NSWindowController(window: window))
    }

    nonisolated public override func read(from data: Data, ofType typeName: String) throws {
        try Self.validateOpenByteCount(data.count)
        let decoded = try TextDecoder.decode(data)
        MainActor.assumeIsolated {
            apply(decoded, typeName: typeName)
        }
    }

    public func read(
        from data: Data,
        ofType typeName: String,
        using encoding: TextEncoding
    ) throws {
        try Self.validateOpenByteCount(data.count)
        apply(
            try TextDecoder.decode(data, reopeningUsing: encoding),
            typeName: typeName
        )
    }

    nonisolated public override func write(to url: URL, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            let writeRevision = revision
            let encoded = try data(ofType: typeName)
            try encoded.write(to: url, options: .atomic)
            pendingWrittenBaseline = SavedBaseline(
                data: encoded,
                revision: writeRevision,
                documentType: typeName
            )
        }
    }

    public override func save(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if saveOperation == .saveOperation {
            switch externalChangeState {
            case .deletedOnDisk:
                completionHandler(TextDocumentError.fileDeletedRequiresSaveAs)
                return
            case .becameReadOnly:
                completionHandler(TextDocumentError.fileReadOnlyRequiresSaveAs)
                return
            case .conflict:
                completionHandler(TextDocumentError.conflictRequiresResolution)
                return
            default:
                break
            }
        }
        super.save(
            to: url,
            ofType: typeName,
            for: saveOperation,
            completionHandler: { [weak self] error in
                Task { @MainActor in
                    if error == nil, saveOperation != .saveToOperation {
                        self?.commitPendingSavedBaseline()
                    } else {
                        self?.pendingWrittenBaseline = nil
                    }
                    completionHandler(error)
                }
            }
        )
    }

    public override func data(ofType typeName: String) throws -> Data {
        if revision == loadedRevision, !metadataHasChanged, let originalData {
            return originalData
        }

        let lineEnding = try effectiveLineEndingForSave()
        return try TextEncoder.encode(
            textStorage.string,
            encoding: metadata.encoding,
            lineEnding: lineEnding
        )
    }

    public func noteTextChange(_ edit: TextEdit? = nil) {
        objectWillChange.send()
        if let edit {
            lineIndex.apply(edit)
            if let removedUTF8Length = edit.removedUTF8Length {
                workingUTF8ByteCount = max(
                    0,
                    workingUTF8ByteCount + edit.replacement.utf8.count - removedUTF8Length
                )
            } else {
                workingUTF8ByteCount = textStorage.string.utf8.count
            }
        } else {
            lineIndex.rebuild(for: textStorage.string)
            workingUTF8ByteCount = textStorage.string.utf8.count
        }
        revision &+= 1
        updateChangeCount(.changeDone)
    }

    public func makeSnapshot() -> DocumentSnapshot {
        DocumentSnapshot(
            text: textStorage.string,
            revision: revision,
            encoding: metadata.encoding,
            lineEnding: metadata.selectedLineEnding ?? metadata.lineEndings.dominant,
            documentType: metadata.documentType,
            fileURL: fileURL,
            utf8ByteCount: workingUTF8ByteCount
        )
    }

    public var largeFileDisposition: LargeFileDisposition {
        LargeFilePolicy.measuredBaseline.disposition(
            forByteCount: max(metadata.sourceByteCount, workingUTF8ByteCount)
        )
    }

    public var markdownPreviewAvailability: MarkdownPreviewAvailability {
        guard metadata.documentType == TildeDocumentType.markdown else {
            return .notMarkdown
        }
        guard LargeFilePolicy.measuredBaseline.allowsMarkdownPreview(
            utf8ByteCount: workingUTF8ByteCount
        ) else {
            return .sourceTooLarge
        }
        return .available
    }

    public var isMarkdownPreviewAllowed: Bool {
        markdownPreviewAvailability == .available
    }

    public func changeEncoding(to encoding: DetectedEncoding) {
        guard metadata.encoding != encoding else { return }
        metadata.encoding = encoding
        noteMetadataChange()
    }

    public func changeLineEnding(to lineEnding: LineEnding) {
        guard metadata.selectedLineEnding != lineEnding else { return }
        metadata.selectedLineEnding = lineEnding
        noteMetadataChange()
    }

    public func reopen(using encoding: TextEncoding) async throws {
        guard let fileURL else { return }
        guard !hasUnsavedChanges else {
            throw TextDocumentError.reopenWouldDiscardChanges
        }
        let decoded = try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            try Self.validateOpenByteCount(data.count)
            return try TextDecoder.decode(data, reopeningUsing: encoding)
        }.value
        apply(decoded, typeName: fileType ?? TildeDocumentType.type(for: fileURL))
        updateChangeCount(.changeCleared)
    }

    public func setExternalChangeState(_ state: ExternalChangeState) {
        objectWillChange.send()
        externalChangeState = state
    }

    public func keepLocalChangesAfterConflict() {
        guard externalChangeState == .conflict else { return }
        setExternalChangeState(.unchanged)
    }

    public func reloadFromDiskDiscardingLocalChanges() async throws {
        guard let fileURL else { return }
        let typeName = fileType ?? TildeDocumentType.type(for: fileURL)
        let decoded = try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            try Self.validateOpenByteCount(data.count)
            return try TextDecoder.decode(data)
        }.value
        apply(decoded, typeName: typeName)
        updateChangeCount(.changeCleared)
    }

    nonisolated public override func presentedItemDidChange() {
        super.presentedItemDidChange()
        Task { @MainActor [weak self] in
            await self?.refreshExternalFileState()
        }
    }

    public func refreshExternalFileState() async {
        guard !isHandlingExternalChange, let fileURL else { return }

        isHandlingExternalChange = true
        defer { isHandlingExternalChange = false }

        do {
            let observation = try await Task.detached(priority: .utility) {
                try Self.inspectExternalFile(at: fileURL)
            }.value

            switch observation {
            case .missing:
                setExternalChangeState(.deletedOnDisk)
                updateChangeCount(.changeDone)
            case let .available(data, isWritable):
                if data == originalData {
                    setExternalChangeState(isWritable ? .unchanged : .becameReadOnly)
                    return
                }

                guard !hasUnsavedChanges else {
                    setExternalChangeState(.conflict)
                    return
                }

                try Self.validateOpenByteCount(data.count)
                let decoded = try TextDecoder.decode(data)
                apply(
                    decoded,
                    typeName: fileType ?? TildeDocumentType.type(for: fileURL)
                )
                updateChangeCount(.changeCleared)
                setExternalChangeState(isWritable ? .unchanged : .becameReadOnly)
            }
        } catch {
            setExternalChangeState(.changedOnDisk)
            presentError(error)
        }
    }

    private func apply(_ decoded: DecodedTextFile, typeName: String) {
        objectWillChange.send()
        textStorage.setAttributedString(NSAttributedString(string: decoded.text))
        metadata = DocumentMetadata(
            encoding: decoded.encoding,
            lineEndings: decoded.lineEndings,
            selectedLineEnding: defaultSelectedLineEnding(for: decoded.lineEndings),
            documentType: typeName,
            sourceByteCount: decoded.originalData.count
        )
        originalData = decoded.originalData
        workingUTF8ByteCount = decoded.text.utf8.count
        lineIndex.rebuild(for: decoded.text)
        revision &+= 1
        loadedRevision = revision
        metadataHasChanged = false
        externalChangeState = .unchanged
    }

    private func defaultSelectedLineEnding(for profile: LineEndingProfile) -> LineEnding? {
        switch profile.kind {
        case .none:
            .lf
        case let .uniform(ending):
            ending
        case .mixed:
            nil
        }
    }

    private func effectiveLineEndingForSave() throws -> LineEnding {
        if let selectedLineEnding = metadata.selectedLineEnding {
            return selectedLineEnding
        }
        if metadata.lineEndings.kind == .mixed, revision != loadedRevision || metadataHasChanged {
            throw TextCodecError.mixedLineEndingsRequireSelection
        }
        return metadata.lineEndings.dominant
    }

    private func noteMetadataChange() {
        objectWillChange.send()
        metadataHasChanged = true
        revision &+= 1
        updateChangeCount(.changeDone)
    }

    private var hasUnsavedChanges: Bool {
        revision != loadedRevision || metadataHasChanged || isDocumentEdited
    }

    private func commitPendingSavedBaseline() {
        guard let baseline = pendingWrittenBaseline else { return }
        pendingWrittenBaseline = nil
        commitSavedBaseline(
            baseline.data,
            revision: baseline.revision,
            documentType: baseline.documentType
        )
    }

    private func commitSavedBaseline(
        _ data: Data,
        revision savedRevision: UInt64,
        documentType: String
    ) {
        guard revision == savedRevision else { return }
        objectWillChange.send()
        originalData = data
        metadata.sourceByteCount = data.count
        metadata.documentType = documentType
        loadedRevision = savedRevision
        metadataHasChanged = false

        let lineCount = LineEndingDetector.normalize(textStorage.string).profile.lfCount
        switch metadata.selectedLineEnding ?? metadata.lineEndings.dominant {
        case .lf:
            metadata.lineEndings = LineEndingProfile(lfCount: lineCount)
        case .crlf:
            metadata.lineEndings = LineEndingProfile(crlfCount: lineCount)
        case .cr:
            metadata.lineEndings = LineEndingProfile(crCount: lineCount)
        }
        externalChangeState = .unchanged
    }

    nonisolated static func validateOpenByteCount(_ byteCount: Int) throws {
        let policy = LargeFilePolicy.measuredBaseline
        guard policy.disposition(forByteCount: byteCount) != .exceedsValidatedLimit else {
            throw TextDocumentError.fileExceedsValidatedLimit(
                actualBytes: byteCount,
                maximumBytes: policy.maximumValidatedEditorBytes
            )
        }
    }

    nonisolated private static func inspectExternalFile(at url: URL) throws -> ExternalFileObservation {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return .missing }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        let modeAllowsWriting = permissions.map { $0 & 0o222 != 0 } ?? true
        let isWritable = modeAllowsWriting && fileManager.isWritableFile(atPath: url.path)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return .available(data: data, isWritable: isWritable)
    }
}

private enum ExternalFileObservation: Sendable {
    case missing
    case available(data: Data, isWritable: Bool)
}

private struct SavedBaseline: Sendable {
    let data: Data
    let revision: UInt64
    let documentType: String
}
