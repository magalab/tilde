import AppKit
import SwiftUI
import TildeCore
import TildeDocument
import TildeEditor

enum EncodingMenuChoice: Int, CaseIterable {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian

    var title: String {
        switch self {
        case .utf8: L10n.string("UTF-8")
        case .utf16LittleEndian: L10n.string("UTF-16 Little Endian")
        case .utf16BigEndian: L10n.string("UTF-16 Big Endian")
        }
    }

    var detectedEncoding: DetectedEncoding {
        switch self {
        case .utf8:
            .newDocumentUTF8
        case .utf16LittleEndian:
            DetectedEncoding(
                encoding: .utf16LittleEndian,
                byteOrder: .littleEndian,
                bomPolicy: .present,
                confidence: .certain
            )
        case .utf16BigEndian:
            DetectedEncoding(
                encoding: .utf16BigEndian,
                byteOrder: .bigEndian,
                bomPolicy: .present,
                confidence: .certain
            )
        }
    }
}

@MainActor
extension AppDelegate {
    @objc func showQuickOpen(_ sender: Any?) {
        showQuickOpenWindow()
    }

    @objc func toggleMarkdownPreview(_ sender: Any?) {
        guard let document = currentDocument else { return }
        NotificationCenter.default.post(name: .toggleMarkdownPreview, object: document)
    }

    @objc func changeDocumentEncoding(_ sender: NSMenuItem) {
        guard let choice = EncodingMenuChoice(rawValue: sender.tag),
              let document = currentDocument
        else { return }
        document.changeEncoding(to: choice.detectedEncoding)
    }

    @objc func reopenDocumentUsingEncoding(_ sender: NSMenuItem) {
        guard let choice = EncodingMenuChoice(rawValue: sender.tag),
              let document = currentDocument
        else { return }
        Task {
            do {
                try await document.reopen(using: choice.detectedEncoding.encoding)
            } catch {
                document.presentError(error)
            }
        }
    }

    @objc func changeDocumentLineEnding(_ sender: NSMenuItem) {
        guard let lineEnding = LineEnding(rawValue: sender.representedObject as? String ?? ""),
              let document = currentDocument
        else { return }
        document.changeLineEnding(to: lineEnding)
    }

    @objc func toggleWordWrap(_ sender: Any?) {
        settings.wordWrap.toggle()
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        settings.showLineNumbers.toggle()
    }

    @objc func changeEditorFont(_ sender: NSMenuItem) {
        guard let fontID = sender.representedObject as? String,
              let font = settings.availableFonts.first(where: { $0.id == fontID })
        else { return }
        settings.fontChoice = font
    }

    @objc func increaseEditorFontSize(_ sender: Any?) {
        settings.increaseFontSize()
    }

    @objc func decreaseEditorFontSize(_ sender: Any?) {
        settings.decreaseFontSize()
    }

    @objc func resetEditorFontSize(_ sender: Any?) {
        settings.resetFontSize()
    }

    @objc func toggleFontLigatures(_ sender: Any?) {
        settings.fontLigatures.toggle()
    }

    @objc func showSettings(_ sender: Any?) {
        let targetScreen = currentDocument?.windowControllers
            .compactMap(\.window?.screen)
            .first
            ?? NSApp.keyWindow?.screen
            ?? NSScreen.main
        if settingsWindowController == nil {
            let hostingController = NSHostingController(rootView: EditorSettingsView(settings: settings))
            let window = NSWindow(contentViewController: hostingController)
            window.title = L10n.string("Tilde Settings")
            window.styleMask = [.titled, .closable]
            window.setContentSize(EditorSettingsView.preferredContentSize)
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(sender)
        guard let window = settingsWindowController?.window else { return }
        window.makeKeyAndOrderFront(sender)
        center(window, on: targetScreen)
        DispatchQueue.main.async { [weak window, weak targetScreen] in
            guard let window else { return }
            window.contentView?.layoutSubtreeIfNeeded()
            self.center(window, on: targetScreen ?? window.screen ?? NSScreen.main)
        }
    }

    private func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else {
            window.center()
            return
        }
        let visibleFrame = screen.visibleFrame
        let windowFrame = window.frame
        window.setFrameOrigin(NSPoint(
            x: round(visibleFrame.midX - windowFrame.width / 2),
            y: round(visibleFrame.midY - windowFrame.height / 2)
        ))
    }

    var currentDocument: TextDocument? {
        NSApp.keyWindow?.windowController?.document as? TextDocument
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(changeDocumentEncoding(_:)):
            guard let document = currentDocument,
                  let choice = EncodingMenuChoice(rawValue: menuItem.tag)
            else { return false }
            let encoding = document.metadata.encoding
            menuItem.state = encoding.encoding == choice.detectedEncoding.encoding ? .on : .off
            return true
        case #selector(reopenDocumentUsingEncoding(_:)):
            return currentDocument?.fileURL != nil && currentDocument?.isDocumentEdited == false
        case #selector(changeDocumentLineEnding(_:)):
            guard let document = currentDocument,
                  let lineEnding = LineEnding(rawValue: menuItem.representedObject as? String ?? "")
            else { return false }
            menuItem.state = document.metadata.selectedLineEnding == lineEnding ? .on : .off
            return true
        case #selector(toggleWordWrap(_:)):
            menuItem.state = settings.wordWrap ? .on : .off
            return currentDocument?.largeFileDisposition == .standard
        case #selector(toggleLineNumbers(_:)):
            menuItem.state = settings.showLineNumbers ? .on : .off
            return currentDocument != nil
        case #selector(toggleMarkdownPreview(_:)):
            return currentDocument?.isMarkdownPreviewAllowed == true
        case #selector(changeEditorFont(_:)):
            guard let fontID = menuItem.representedObject as? String else { return false }
            menuItem.state = settings.fontChoice.id == fontID ? .on : .off
            return true
        case #selector(increaseEditorFontSize(_:)):
            return settings.fontSize < 72
        case #selector(decreaseEditorFontSize(_:)):
            return settings.fontSize > 8
        case #selector(resetEditorFontSize(_:)):
            return settings.fontSize != 13
        case #selector(toggleFontLigatures(_:)):
            menuItem.state = settings.fontLigatures ? .on : .off
            return currentDocument != nil
        default:
            return true
        }
    }
}

extension Notification.Name {
    static let toggleMarkdownPreview = Notification.Name("Tilde.toggleMarkdownPreview")
}
