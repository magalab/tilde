import AppKit
import TildeCore

@MainActor
public final class EditorTextView: NSTextView {
    public var indentStyle: IndentStyle = .spaces
    public var tabWidth = 2
    public var markdownEditingEnabled = false
    public var magnificationHandler: (@MainActor (CGFloat) -> Void)?
    public var smartMagnificationHandler: (@MainActor () -> Void)?
    private var rectangularSelectionAnchor: NSPoint?

    public override func magnify(with event: NSEvent) {
        magnificationHandler?(event.magnification)
    }

    public override func smartMagnify(with event: NSEvent) {
        smartMagnificationHandler?()
    }

    public override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           markdownEditingEnabled,
           openMarkdownLink(at: event)
        {
            return
        }
        if event.modifierFlags.contains(.option),
           !event.modifierFlags.contains(.command),
           layoutManager != nil,
           textContainer != nil
        {
            window?.makeFirstResponder(self)
            let point = convert(event.locationInWindow, from: nil)
            rectangularSelectionAnchor = point
            updateRectangularSelection(to: point)
            return
        }
        super.mouseDown(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard rectangularSelectionAnchor != nil else {
            super.mouseDragged(with: event)
            return
        }
        updateRectangularSelection(to: convert(event.locationInWindow, from: nil))
    }

    public override func mouseUp(with event: NSEvent) {
        guard rectangularSelectionAnchor != nil else {
            super.mouseUp(with: event)
            return
        }
        updateRectangularSelection(to: convert(event.locationInWindow, from: nil))
        rectangularSelectionAnchor = nil
    }

    public override func insertNewline(_ sender: Any?) {
        guard !hasMarkedText(),
              selectedRanges.count == 1,
              selectedRange().length == 0,
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
        guard !hasMarkedText() else {
            super.insertTab(sender)
            return
        }
        if selectedRanges.count > 1 || selectedRange().length > 0 {
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
        guard !hasMarkedText() else {
            super.insertBacktab(sender)
            return
        }
        outdentSelection(sender)
    }

    @objc public func indentSelection(_ sender: Any?) {
        guard !hasMarkedText() else { return }
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
        guard !hasMarkedText() else { return }
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

    @objc public func selectNextOccurrence(_ sender: Any?) {
        let ranges = selectedRanges.map(\.rangeValue)
        guard let primary = ranges.first,
              primary.length > 0,
              let searchRange = nextOccurrenceRange(
                  of: (string as NSString).substring(with: primary),
                  after: ranges.map { $0.location + $0.length }.max() ?? primary.location
              )
        else {
            NSSound.beep()
            return
        }
        var updated = ranges
        guard !updated.contains(searchRange) else { return }
        updated.append(searchRange)
        updated.sort { $0.location < $1.location }
        setSelectedRanges(
            updated.map { NSValue(range: $0) },
            affinity: .downstream,
            stillSelecting: false
        )
    }

    private func nextOccurrenceRange(of value: String, after location: Int) -> NSRange? {
        let source = string as NSString
        let start = min(max(0, location), source.length)
        let forward = source.range(of: value, options: [], range: NSRange(location: start, length: source.length - start))
        if forward.location != NSNotFound { return forward }
        let wrapped = source.range(of: value, options: [], range: NSRange(location: 0, length: start))
        return wrapped.location == NSNotFound ? nil : wrapped
    }

    private func updateRectangularSelection(to point: NSPoint) {
        guard let anchor = rectangularSelectionAnchor,
              let layoutManager,
              let textContainer
        else { return }

        let containerOrigin = textContainerOrigin
        let start = NSPoint(
            x: min(anchor.x, point.x) - containerOrigin.x,
            y: min(anchor.y, point.y) - containerOrigin.y
        )
        let end = NSPoint(
            x: max(anchor.x, point.x) - containerOrigin.x,
            y: max(anchor.y, point.y) - containerOrigin.y
        )
        let verticalRange = NSRange(
            location: max(0, Int(floor(start.y))),
            length: max(1, Int(ceil(end.y - start.y)))
        )
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: NSRect(
                x: 0,
                y: CGFloat(verticalRange.location),
                width: max(1, textContainer.containerSize.width),
                height: CGFloat(verticalRange.length)
            ),
            in: textContainer
        )

        var ranges: [NSRange] = []
        var glyphIndex = glyphRange.location
        let glyphEnd = NSMaxRange(glyphRange)
        while glyphIndex < glyphEnd {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineGlyphRange
            )
            if lineRect.maxY >= start.y, lineRect.minY <= end.y {
                let left = layoutManager.characterIndex(
                    for: NSPoint(x: start.x, y: lineRect.midY),
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: nil
                )
                let right = layoutManager.characterIndex(
                    for: NSPoint(x: end.x, y: lineRect.midY),
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: nil
                )
                let lineCharacterRange = layoutManager.characterRange(
                    forGlyphRange: lineGlyphRange,
                    actualGlyphRange: nil
                )
                let lineStart = lineCharacterRange.location
                let lineEnd = NSMaxRange(lineCharacterRange)
                let lower = min(max(left, lineStart), lineEnd)
                let upper = min(max(right, lineStart), lineEnd)
                ranges.append(NSRange(location: min(lower, upper), length: abs(upper - lower)))
            }
            let nextGlyph = NSMaxRange(lineGlyphRange)
            guard nextGlyph > glyphIndex else { break }
            glyphIndex = nextGlyph
        }

        guard !ranges.isEmpty else { return }
        setSelectedRanges(
            ranges.map { NSValue(range: $0) },
            affinity: .downstream,
            stillSelecting: true
        )
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

    private func openMarkdownLink(at event: NSEvent) -> Bool {
        guard let layoutManager,
              let textContainer,
              let coordinator = delegate as? EditorCoordinator
        else { return false }
        let point = convert(event.locationInWindow, from: nil)
        let characterIndex = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard characterIndex < string.utf16.count else { return false }

        let expression = try? NSRegularExpression(
            pattern: #"!?(?:\[([^\]\n]+)\])\(([^)\n]+)\)"#
        )
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard let match = expression?.matches(in: string, range: fullRange).first(where: {
            NSLocationInRange(characterIndex, $0.range)
        }),
              let destinationRange = Range(match.range(at: 2), in: string)
        else { return false }

        let destination = String(string[destinationRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if destination.hasPrefix("#") {
            let anchor = String(destination.dropFirst())
            if let heading = MarkdownOutlineParser.headings(in: string).first(where: {
                MarkdownOutlineParser.slug(for: $0.title) == MarkdownOutlineParser.slug(for: anchor)
            }) {
                goToLine(heading.line)
                return true
            }
            return false
        }
        guard let url = coordinator.document.destinationURL(forMarkdownLink: destination)
        else { return false }
        NSWorkspace.shared.open(url)
        return true
    }
}
