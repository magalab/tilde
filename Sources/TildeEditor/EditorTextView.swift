import AppKit
import TildeCore

@MainActor
public final class EditorTextView: NSTextView {
    public var indentStyle: IndentStyle = .spaces
    public var tabWidth = 2
    public var markdownEditingEnabled = false
    public var magnificationHandler: (@MainActor (CGFloat) -> Void)?
    public var smartMagnificationHandler: (@MainActor () -> Void)?

    public override func magnify(with event: NSEvent) {
        magnificationHandler?(event.magnification)
    }

    public override func smartMagnify(with event: NSEvent) {
        smartMagnificationHandler?()
    }

    public override func insertNewline(_ sender: Any?) {
        guard selectedRange().length == 0,
              markdownEditingEnabled,
              let edit = MarkdownEditingTransformer.newlineEdit(
                in: string,
                cursor: selectedRange().location
              )
        else {
            super.insertNewline(sender)
            return
        }
        insertText(edit.replacement, replacementRange: edit.range)
    }

    public override func insertTab(_ sender: Any?) {
        if selectedRange().length > 0 {
            indentSelection(sender)
            return
        }
        guard indentStyle == .spaces else {
            super.insertTab(sender)
            return
        }

        let spaces = String(repeating: " ", count: tabWidth)
        insertText(spaces, replacementRange: selectedRange())
    }

    public override func insertBacktab(_ sender: Any?) {
        outdentSelection(sender)
    }

    @objc public func indentSelection(_ sender: Any?) {
        guard let edit = IndentationTransformer.indent(
            text: string,
            selection: selectedRange(),
            style: indentStyle,
            width: tabWidth
        ) else { return }
        insertText(edit.replacement, replacementRange: edit.range)
        setSelectedRange(edit.selection)
    }

    @objc public func outdentSelection(_ sender: Any?) {
        guard let edit = IndentationTransformer.outdent(
            text: string,
            selection: selectedRange(),
            width: tabWidth
        ) else {
            NSSound.beep()
            return
        }
        insertText(edit.replacement, replacementRange: edit.range)
        setSelectedRange(edit.selection)
    }

    @objc public func showGoToLinePanel(_ sender: Any?) {
        let input = NSTextField(string: "")
        input.placeholderString = L10n.string("Line number")
        let alert = NSAlert()
        alert.messageText = L10n.string("Go to Line")
        alert.informativeText = L10n.string("Enter a line number.")
        alert.accessoryView = input
        alert.addButton(withTitle: L10n.string("Go"))
        alert.addButton(withTitle: L10n.string("Cancel"))

        let complete: @MainActor (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  let self,
                  let line = Int(input.stringValue),
                  line > 0
            else { return }
            self.goToLine(line)
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: complete)
        } else {
            complete(alert.runModal())
        }
    }

    public func goToLine(_ line: Int) {
        guard let document = delegate as? EditorCoordinator,
              let offset = document.document.lineIndex.offset(forLine: line)
        else {
            NSSound.beep()
            return
        }
        setSelectedRange(NSRange(location: offset, length: 0))
        scrollRangeToVisible(selectedRange())
        window?.makeFirstResponder(self)
    }
}
