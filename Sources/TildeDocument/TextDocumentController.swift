import AppKit
import Foundation
import TildeCore

@MainActor
public final class TextDocumentController: NSDocumentController {
    public var newDocumentMetadataProvider: @MainActor () -> DocumentMetadata = {
        DocumentMetadata()
    }

    public override var defaultType: String? { TildeDocumentType.plainText }

    public override var documentClassNames: [String] {
        [NSStringFromClass(TextDocument.self)]
    }

    public override func documentClass(forType typeName: String) -> AnyClass? {
        switch typeName {
        case TildeDocumentType.plainText, TildeDocumentType.markdown:
            TextDocument.self
        default:
            nil
        }
    }

    public override func typeForContents(of url: URL) throws -> String {
        TildeDocumentType.type(for: url)
    }

    // NSDocumentController requires `throws` in this override even though this concrete
    // document factory has no failing operations.
    public override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        makeTextUntitledDocument(ofType: typeName)
    }

    private func makeTextUntitledDocument(ofType typeName: String) -> TextDocument {
        let document = TextDocument()
        document.fileType = typeName
        document.configureNewDocument(metadata: newDocumentMetadataProvider())
        return document
    }

    public func makeAndShowUntitledDocument(disallowTabbing: Bool = false) -> TextDocument {
        let document = makeTextUntitledDocument(
            ofType: defaultType ?? TildeDocumentType.plainText
        )
        addDocument(document)
        configure(document: document)
        document.makeWindowControllers()
        if disallowTabbing {
            document.windowControllers.forEach { controller in
                controller.window?.tabbingMode = .disallowed
            }
        }
        document.showWindows()
        return document
    }

    public func newDocumentInSeparateWindow() {
        _ = makeAndShowUntitledDocument(disallowTabbing: true)
    }

    public override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void
    ) {
        let securityScopedAccess = SecurityScopedAccess(url: url)

        super.openDocument(withContentsOf: url, display: displayDocument) { [weak self] document, wasAlreadyOpen, error in
            guard let self else {
                completionHandler(document, wasAlreadyOpen, error)
                return
            }

            if let error, self.shouldOfferEncodingChooser(for: error) {
                guard let encoding = self.chooseEncoding(for: url) else {
                    completionHandler(nil, false, error)
                    return
                }

                do {
                    let document = try self.openDocument(
                        at: url,
                        using: encoding,
                        display: displayDocument,
                        securityScopedAccess: securityScopedAccess,
                        installFileURLChangeHandler: true
                    )
                    completionHandler(document, false, nil)
                } catch {
                    completionHandler(nil, false, error)
                }
                return
            }

            guard let document else {
                completionHandler(nil, wasAlreadyOpen, error)
                return
            }

            if wasAlreadyOpen {
                completionHandler(document, wasAlreadyOpen, error)
                return
            }

            if securityScopedAccess.isActive {
                configure(document: document)
                retainSecurityScopedAccess(
                    for: document,
                    access: securityScopedAccess
                )
            }
            completionHandler(document, wasAlreadyOpen, error)
        }
    }

    public override func removeDocument(_ document: NSDocument) {
        (document as? TextDocument)?.releaseSecurityScopedAccess()
        super.removeDocument(document)
    }

    /// Releases any remaining file access during application termination.
    ///
    /// Normal document closure is handled by removeDocument(_:); this is only a
    /// final safety net for documents still open while the application exits.
    public func releaseRetainedSecurityScopedAccess() {
        documents
            .compactMap { $0 as? TextDocument }
            .forEach { $0.releaseSecurityScopedAccess() }
    }

    public func openDocument(
        at url: URL,
        using encoding: TextEncoding,
        display: Bool
    ) throws -> TextDocument {
        try openDocument(
            at: url,
            using: encoding,
            display: display,
            securityScopedAccess: nil,
            installFileURLChangeHandler: false
        )
    }

    func documentFileURLDidChange(_ document: TextDocument) {
        document.releaseSecurityScopedAccessIfFileURLChanged()
        document.windowControllers.forEach { controller in
            controller.window?.isRestorable = document.fileURL != nil
        }
    }

    private func openDocument(
        at url: URL,
        using encoding: TextEncoding,
        display: Bool,
        securityScopedAccess: SecurityScopedAccess?,
        installFileURLChangeHandler: Bool
    ) throws -> TextDocument {
        let typeName = try typeForContents(of: url)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let document = TextDocument()
        document.fileURL = url
        document.fileType = typeName
        try document.read(from: data, ofType: typeName, using: encoding)
        addDocument(document)
        noteNewRecentDocumentURL(url)
        if installFileURLChangeHandler {
            configure(document: document)
        }
        if let securityScopedAccess, securityScopedAccess.isActive {
            retainSecurityScopedAccess(
                for: document,
                access: securityScopedAccess
            )
        }
        if display {
            document.makeWindowControllers()
            document.showWindows()
        }
        return document
    }

    private func configure(document: NSDocument) {
        guard let document = document as? TextDocument else { return }
        document.fileURLDidChangeHandler = { [weak self] changedDocument in
            self?.documentFileURLDidChange(changedDocument)
        }
    }

    private func retainSecurityScopedAccess(
        for document: NSDocument,
        access: SecurityScopedAccess
    ) {
        (document as? TextDocument)?.retainSecurityScopedAccess(access)
    }

    private func chooseEncoding(for url: URL) -> TextEncoding? {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        for encoding in TextEncoding.allCases {
            popup.addItem(withTitle: encoding.localizedName)
            popup.lastItem?.representedObject = encoding.rawValue
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.string("Choose Text Encoding")
        alert.informativeText = L10n.format(
            "“%@” could not be decoded reliably. Choose an encoding to open it without replacing invalid bytes.",
            url.lastPathComponent
        )
        alert.accessoryView = popup
        alert.addButton(withTitle: L10n.string("Open"))
        alert.addButton(withTitle: L10n.string("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn,
              let rawValue = popup.selectedItem?.representedObject as? String
        else { return nil }
        return TextEncoding(rawValue: rawValue)
    }

    private func shouldOfferEncodingChooser(for error: Error) -> Bool {
        if let codecError = error as? TextCodecError {
            return codecError == .unsupportedOrInvalidEncoding || codecError == .malformedUTF16
        }
        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           (underlying as NSError) != nsError
        {
            return shouldOfferEncodingChooser(for: underlying)
        }
        return false
    }
}

final class SecurityScopedAccess {
    let url: URL
    private(set) var isActive: Bool

    init(url: URL) {
        self.url = url
        isActive = url.startAccessingSecurityScopedResource()
    }

    func stop() {
        guard isActive else { return }
        url.stopAccessingSecurityScopedResource()
        isActive = false
    }

    deinit {
        stop()
    }
}
