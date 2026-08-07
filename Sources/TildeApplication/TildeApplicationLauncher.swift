import AppKit
import TildeCore
import TildeDocument
import TildeEditor

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let documentController = TextDocumentController()
    let settings = EditorSettings()
    var settingsWindowController: NSWindowController?
    private var fontSizeKeyMonitor: Any?

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
        installFontSizeKeyMonitor()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if documentController.documents.isEmpty {
            documentController.newDocument(nil)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func newDocumentInNewWindow(_ sender: Any?) {
        documentController.newDocumentInSeparateWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let fontSizeKeyMonitor {
            NSEvent.removeMonitor(fontSizeKeyMonitor)
            self.fontSizeKeyMonitor = nil
        }
    }

    private func installFontSizeKeyMonitor() {
        fontSizeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            @MainActor [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains(.command),
                  !modifiers.contains(.control),
                  !modifiers.contains(.option),
                  let key = event.charactersIgnoringModifiers
            else { return event }

            switch key {
            case "=", "+":
                self.settings.increaseFontSize()
                return nil
            case "-":
                self.settings.decreaseFontSize()
                return nil
            default:
                return event
            }
        }
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
