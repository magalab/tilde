import AppKit
import TildeCore
import TildeEditor

@MainActor
enum MainMenuBuilder {
    static func make(
        documentController: NSDocumentController,
        actionTarget: AppDelegate
    ) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenu(actionTarget: actionTarget))
        mainMenu.addItem(fileMenu(documentController: documentController, actionTarget: actionTarget))
        mainMenu.addItem(editMenu())
        mainMenu.addItem(formatMenu(actionTarget: actionTarget))
        mainMenu.addItem(viewMenu(actionTarget: actionTarget))
        mainMenu.addItem(navigationMenu())
        mainMenu.addItem(windowMenu())
        return mainMenu
    }

    private static func appMenu(actionTarget: AppDelegate) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: "Tilde")
        menu.addItem(withTitle: L10n.string("About Tilde"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let settings = menu.addItem(withTitle: L10n.string("Settings…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        settings.target = actionTarget
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Hide Tilde"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: L10n.string("Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: L10n.string("Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Quit Tilde"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = menu
        return root
    }

    private static func fileMenu(
        documentController: NSDocumentController,
        actionTarget: AppDelegate
    ) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: L10n.string("File"))
        let new = menu.addItem(withTitle: L10n.string("New Tab"), action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        new.target = documentController
        let newWindow = menu.addItem(
            withTitle: L10n.string("New Window"),
            action: #selector(AppDelegate.newDocumentInNewWindow(_:)),
            keyEquivalent: "N"
        )
        newWindow.keyEquivalentModifierMask = [.command, .shift]
        newWindow.target = actionTarget
        let open = menu.addItem(withTitle: L10n.string("Open…"), action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        open.target = documentController
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: L10n.string("Save"), action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        let saveAs = menu.addItem(withTitle: L10n.string("Save As…"), action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(withTitle: L10n.string("Revert to Saved"), action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(encodingMenu(actionTarget: actionTarget))
        menu.addItem(lineEndingMenu(actionTarget: actionTarget))
        root.submenu = menu
        return root
    }

    private static func encodingMenu(actionTarget: AppDelegate) -> NSMenuItem {
        let root = NSMenuItem(title: L10n.string("Encoding"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L10n.string("Encoding"))

        let changeRoot = NSMenuItem(title: L10n.string("Change Document Encoding"), action: nil, keyEquivalent: "")
        let changeMenu = NSMenu(title: L10n.string("Change Document Encoding"))
        let reopenRoot = NSMenuItem(title: L10n.string("Reopen Using Encoding"), action: nil, keyEquivalent: "")
        let reopenMenu = NSMenu(title: L10n.string("Reopen Using Encoding"))

        for choice in EncodingMenuChoice.allCases {
            let change = changeMenu.addItem(
                withTitle: choice.title,
                action: #selector(AppDelegate.changeDocumentEncoding(_:)),
                keyEquivalent: ""
            )
            change.target = actionTarget
            change.tag = choice.rawValue

            let reopen = reopenMenu.addItem(
                withTitle: choice.title,
                action: #selector(AppDelegate.reopenDocumentUsingEncoding(_:)),
                keyEquivalent: ""
            )
            reopen.target = actionTarget
            reopen.tag = choice.rawValue
        }

        changeRoot.submenu = changeMenu
        reopenRoot.submenu = reopenMenu
        menu.addItem(changeRoot)
        menu.addItem(reopenRoot)
        root.submenu = menu
        return root
    }

    private static func lineEndingMenu(actionTarget: AppDelegate) -> NSMenuItem {
        let root = NSMenuItem(title: L10n.string("Line Endings"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L10n.string("Line Endings"))
        for lineEnding in LineEnding.allCases {
            let item = menu.addItem(
                withTitle: lineEnding.localizedName,
                action: #selector(AppDelegate.changeDocumentLineEnding(_:)),
                keyEquivalent: ""
            )
            item.target = actionTarget
            item.representedObject = lineEnding.rawValue
        }
        root.submenu = menu
        return root
    }

    private static func editMenu() -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: L10n.string("Edit"))
        menu.addItem(withTitle: L10n.string("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: L10n.string("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: L10n.string("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: L10n.string("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: L10n.string("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(.separator())
        let find = menu.addItem(withTitle: L10n.string("Find…"), action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
        let next = menu.addItem(withTitle: L10n.string("Find Next"), action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
        next.tag = Int(NSTextFinder.Action.nextMatch.rawValue)
        let previous = menu.addItem(withTitle: L10n.string("Find Previous"), action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "G")
        previous.keyEquivalentModifierMask = [.command, .shift]
        previous.tag = Int(NSTextFinder.Action.previousMatch.rawValue)
        let replace = menu.addItem(withTitle: L10n.string("Find and Replace…"), action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        replace.keyEquivalentModifierMask = [.command, .option]
        replace.tag = Int(NSTextFinder.Action.showReplaceInterface.rawValue)
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Indent Selection"), action: #selector(EditorTextView.indentSelection(_:)), keyEquivalent: "]")
        menu.addItem(withTitle: L10n.string("Outdent Selection"), action: #selector(EditorTextView.outdentSelection(_:)), keyEquivalent: "[")
        let nextOccurrence = menu.addItem(
            withTitle: L10n.string("Add Selection to Next Match"),
            action: #selector(EditorTextView.selectNextOccurrence(_:)),
            keyEquivalent: "d"
        )
        nextOccurrence.keyEquivalentModifierMask = [.command]
        root.submenu = menu
        return root
    }

    private static func viewMenu(actionTarget: AppDelegate) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: L10n.string("View"))
        let preview = menu.addItem(
            withTitle: L10n.string("Preview Markdown"),
            action: #selector(AppDelegate.toggleMarkdownPreview(_:)),
            keyEquivalent: ""
        )
        preview.target = actionTarget
        let wrap = menu.addItem(
            withTitle: L10n.string("Word Wrap"),
            action: #selector(AppDelegate.toggleWordWrap(_:)),
            keyEquivalent: ""
        )
        wrap.target = actionTarget
        let lineNumbers = menu.addItem(
            withTitle: L10n.string("Line Numbers"),
            action: #selector(AppDelegate.toggleLineNumbers(_:)),
            keyEquivalent: ""
        )
        lineNumbers.target = actionTarget
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Enter Full Screen"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.command, .control]
        root.submenu = menu
        return root
    }

    private static func formatMenu(actionTarget: AppDelegate) -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: L10n.string("Format"))

        let fontRoot = NSMenuItem(title: L10n.string("Font"), action: nil, keyEquivalent: "")
        let fontMenu = NSMenu(title: L10n.string("Font"))
        for (index, choice) in actionTarget.settings.availableFonts.enumerated() {
            if index == 1 {
                fontMenu.addItem(.separator())
            }
            let item = fontMenu.addItem(
                withTitle: choice.title,
                action: #selector(AppDelegate.changeEditorFont(_:)),
                keyEquivalent: ""
            )
            item.target = actionTarget
            item.representedObject = choice.id
        }
        fontMenu.addItem(.separator())
        let bigger = fontMenu.addItem(
            withTitle: L10n.string("Bigger"),
            action: #selector(AppDelegate.increaseEditorFontSize(_:)),
            keyEquivalent: "+"
        )
        bigger.target = actionTarget
        bigger.keyEquivalentModifierMask = [.command]
        let smaller = fontMenu.addItem(
            withTitle: L10n.string("Smaller"),
            action: #selector(AppDelegate.decreaseEditorFontSize(_:)),
            keyEquivalent: "-"
        )
        smaller.target = actionTarget
        smaller.keyEquivalentModifierMask = [.command]
        let reset = fontMenu.addItem(
            withTitle: L10n.string("Reset Size"),
            action: #selector(AppDelegate.resetEditorFontSize(_:)),
            keyEquivalent: "0"
        )
        reset.target = actionTarget
        reset.keyEquivalentModifierMask = [.command]
        fontMenu.addItem(.separator())
        let ligatures = fontMenu.addItem(
            withTitle: L10n.string("Ligatures"),
            action: #selector(AppDelegate.toggleFontLigatures(_:)),
            keyEquivalent: ""
        )
        ligatures.target = actionTarget
        fontRoot.submenu = fontMenu
        menu.addItem(fontRoot)

        root.submenu = menu
        return root
    }

    private static func navigationMenu() -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: L10n.string("Navigation"))
        let quickOpen = menu.addItem(
            withTitle: L10n.string("Quick Open…"),
            action: #selector(AppDelegate.showQuickOpen(_:)),
            keyEquivalent: "p"
        )
        quickOpen.target = NSApp.delegate
        let commandPalette = menu.addItem(
            withTitle: L10n.string("Command Palette…"),
            action: #selector(AppDelegate.showCommandPalette(_:)),
            keyEquivalent: "P"
        )
        commandPalette.keyEquivalentModifierMask = [.command, .shift]
        commandPalette.target = NSApp.delegate
        let outline = menu.addItem(
            withTitle: L10n.string("Document Outline…"),
            action: #selector(AppDelegate.showDocumentOutline(_:)),
            keyEquivalent: "o"
        )
        outline.keyEquivalentModifierMask = [.command, .shift]
        outline.target = NSApp.delegate
        menu.addItem(.separator())
        let goToLine = menu.addItem(
            withTitle: L10n.string("Go to Line…"),
            action: #selector(EditorTextView.showGoToLinePanel(_:)),
            keyEquivalent: "l"
        )
        goToLine.keyEquivalentModifierMask = [.command, .control]
        let back = menu.addItem(
            withTitle: L10n.string("Back"),
            action: #selector(AppDelegate.navigateBack(_:)),
            keyEquivalent: "\u{F702}"
        )
        back.keyEquivalentModifierMask = [.command, .option]
        back.target = NSApp.delegate
        let forward = menu.addItem(
            withTitle: L10n.string("Forward"),
            action: #selector(AppDelegate.navigateForward(_:)),
            keyEquivalent: "\u{F703}"
        )
        forward.keyEquivalentModifierMask = [.command, .option]
        forward.target = NSApp.delegate
        root.submenu = menu
        return root
    }

    private static func windowMenu() -> NSMenuItem {
        let root = NSMenuItem()
        let menu = NSMenu(title: L10n.string("Window"))
        menu.addItem(withTitle: L10n.string("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: L10n.string("Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        root.submenu = menu
        return root
    }
}
