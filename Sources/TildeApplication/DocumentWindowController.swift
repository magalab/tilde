import AppKit
import SwiftUI
import TildeDocument
import TildeEditor

@MainActor
final class DocumentWindowController: NSWindowController {
    private let openingMode: WindowOpeningMode
    private var hasAppliedOpeningMode = false

    init(document: TextDocument, settings: EditorSettings) {
        openingMode = settings.windowOpeningMode
        let rootView = DocumentRootView(document: document, settings: settings)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 780, height: 560))
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
        window.titleVisibility = .visible
        window.tabbingMode = .preferred
        window.isRestorable = true
        super.init(window: window)
        shouldCascadeWindows = true
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard !hasAppliedOpeningMode, let window else { return }
        hasAppliedOpeningMode = true

        switch openingMode {
        case .normal:
            break
        case .maximized:
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(screen.visibleFrame, display: true)
            }
        case .fullScreen:
            DispatchQueue.main.async { [weak window] in
                guard let window, !window.styleMask.contains(.fullScreen) else { return }
                window.toggleFullScreen(nil)
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }
}
