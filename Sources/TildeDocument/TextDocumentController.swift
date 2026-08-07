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

    public override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = TextDocument()
        document.fileType = typeName
        document.configureNewDocument(metadata: newDocumentMetadataProvider())
        return document
    }

    public override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void
    ) {
        super.openDocument(withContentsOf: url, display: displayDocument) { [weak self] document, wasAlreadyOpen, error in
            guard let self,
                  let error,
                  self.shouldOfferEncodingChooser(for: error)
            else {
                completionHandler(document, wasAlreadyOpen, error)
                return
            }

            guard let encoding = self.chooseEncoding(for: url) else {
                completionHandler(nil, false, error)
                return
            }

            do {
                let document = try self.openDocument(
                    at: url,
                    using: encoding,
                    display: displayDocument
                )
                completionHandler(document, false, nil)
            } catch {
                completionHandler(nil, false, error)
            }
        }
    }

    public func openDocument(
        at url: URL,
        using encoding: TextEncoding,
        display: Bool
    ) throws -> TextDocument {
        let typeName = try typeForContents(of: url)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let document = TextDocument()
        document.fileURL = url
        document.fileType = typeName
        try document.read(from: data, ofType: typeName, using: encoding)
        addDocument(document)
        noteNewRecentDocumentURL(url)
        if display {
            document.makeWindowControllers()
            document.showWindows()
        }
        return document
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
