import AppKit
import TildeCore
import TildeDocument
import TildeEditor

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let documentController = TextDocumentController()
    let settings = EditorSettings()
    var settingsWindowController: NSWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        documentController.newDocumentMetadataProvider = { [settings] in
            DocumentMetadata(
                encoding: settings.defaultEncoding.detectedEncoding,
                lineEndings: LineEndingProfile(),
                selectedLineEnding: settings.defaultLineEnding,
                documentType: TildeDocumentType.plainText
            )
        }
        TextDocument.windowControllerFactory = { [settings] document in
            DocumentWindowController(document: document, settings: settings)
        }
        NSApp.mainMenu = MainMenuBuilder.make(
            documentController: documentController,
            actionTarget: self
        )
        NSApp.windowsMenu = NSApp.mainMenu?.item(withTitle: L10n.string("Window"))?.submenu
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func newDocumentInNewWindow(_ sender: Any?) {
        documentController.newDocumentInSeparateWindow()
    }

}

public enum TildeApplicationLauncher {
    @MainActor
    public static func run() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
