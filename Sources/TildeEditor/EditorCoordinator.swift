import AppKit
import TildeCore
import TildeDocument

@MainActor
public final class EditorCoordinator: NSObject, NSTextViewDelegate {
    public let document: TextDocument
    private let session: EditorSession
    private var pendingEdit: TextEdit?
    private var boundsObserver: NSObjectProtocol?
    private var syntaxHighlighter: MarkdownSyntaxHighlighter?
    private var highlightedRevision: UInt64?
    private var lastObservedRevision: UInt64?
    private var syntaxPalette = EditorThemePalette.light
    private var currentLineRange: NSRange?
    private var matchingDelimiterRanges: [NSRange] = []
    var presentationState: EditorPresentationState?

    init(document: TextDocument, session: EditorSession) {
        self.document = document
        self.session = session
    }

    func stopObservingScrollView() {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
            self.boundsObserver = nil
        }
    }

    func observeScrollView(_ scrollView: NSScrollView) {
        scrollView.contentView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self, weak scrollView] _ in
            MainActor.assumeIsolated {
                guard let self, let scrollView else { return }
                self.session.scrollPosition = scrollView.contentView.bounds.origin
                (scrollView.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
            }
        }
    }

    func refreshSyntaxHighlighting(
        in textView: NSTextView,
        palette: EditorThemePalette,
        edit: TextEdit? = nil
    ) {
        if edit == nil,
           let lastObservedRevision,
           lastObservedRevision != document.revision
        {
            session.clearNavigationHistory()
        }
        self.lastObservedRevision = document.revision
        if syntaxPalette != palette {
            stopSyntaxHighlighting()
            syntaxPalette = palette
        }
        guard let layoutManager = textView.layoutManager else { return }
        let policy = LargeFilePolicy.measuredBaseline
        let shouldHighlight = document.metadata.documentType == TildeDocumentType.markdown
            && document.workingUTF8ByteCount <= policy.maximumMarkdownPreviewBytes

        guard shouldHighlight else {
            syntaxHighlighter?.clearAll()
            syntaxHighlighter = nil
            highlightedRevision = document.revision
            return
        }

        if syntaxHighlighter == nil {
            syntaxHighlighter = MarkdownSyntaxHighlighter(
                layoutManager: layoutManager,
                textStorage: document.textStorage,
                palette: palette
            )
            syntaxHighlighter?.highlightAll()
        } else if let edit {
            syntaxHighlighter?.highlight(edit: edit)
        } else if highlightedRevision != document.revision {
            syntaxHighlighter?.highlightAll()
        }
        highlightedRevision = document.revision
    }

    func stopSyntaxHighlighting() {
        syntaxHighlighter?.clearAll()
        syntaxHighlighter = nil
        highlightedRevision = nil
    }

    public func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        let storage = textView.textStorage?.mutableString
        let safeRange = NSIntersectionRange(
            affectedCharRange,
            NSRange(location: 0, length: storage?.length ?? 0)
        )
        let removedUTF8Length = storage?
            .substring(with: safeRange)
            .utf8.count ?? 0
        pendingEdit = TextEdit(
            range: affectedCharRange,
            replacement: replacementString ?? "",
            removedUTF8Length: removedUTF8Length
        )
        return true
    }

    public func textDidChange(_ notification: Notification) {
        let appliedEdit = pendingEdit
        document.noteTextChange(appliedEdit)
        pendingEdit = nil
        let textView = notification.object as? NSTextView
        if let textView {
            let levels = document.largeFileDisposition == .standard ? 0 : 50
            if textView.undoManager?.levelsOfUndo != levels {
                textView.undoManager?.levelsOfUndo = levels
            }
        }
        if let textView {
            refreshSyntaxHighlighting(in: textView, palette: syntaxPalette, edit: appliedEdit)
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?
                .invalidateLineNumbers()
            refreshSelectionDecorations(in: textView)
        }
        updateSelection(from: textView)
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
        updateSelection(from: notification.object as? NSTextView)
    }

    private func updateSelection(from textView: NSTextView?) {
        guard let textView else { return }
        let selections = textView.selectedRanges.map(\.rangeValue)
        guard let selection = selections.first else { return }
        session.selection = selection
        session.selectedRanges = selections
        session.textPosition = document.lineIndex.position(
            forUTF16Offset: selection.location,
            in: document.textStorage.mutableString
        )
        refreshSelectionDecorations(in: textView)
    }

    func recordNavigationLocation(beforeNavigatingTo destination: NSRange) {
        session.recordNavigationLocation(session.selection, beforeNavigatingTo: destination)
    }

    var canNavigateBack: Bool { session.canNavigateBack }
    var canNavigateForward: Bool { session.canNavigateForward }

    func navigateBack(in textView: NSTextView) {
        guard let destination = session.navigateBack(
            from: textView.selectedRange(),
            maximumLength: textView.string.utf16.count
        ) else {
            NSSound.beep()
            return
        }
        textView.setSelectedRange(destination)
        textView.scrollRangeToVisible(destination)
    }

    func navigateForward(in textView: NSTextView) {
        guard let destination = session.navigateForward(
            from: textView.selectedRange(),
            maximumLength: textView.string.utf16.count
        ) else {
            NSSound.beep()
            return
        }
        textView.setSelectedRange(destination)
        textView.scrollRangeToVisible(destination)
    }

    func refreshSelectionDecorations(in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage
        else { return }

        if let currentLineRange {
            removeTemporaryAttribute(
                .backgroundColor,
                forRange: currentLineRange,
                layoutManager: layoutManager,
                textLength: textStorage.length
            )
        }
        let textLength = textStorage.length
        if textLength > 0 {
            let location = min(textView.selectedRange().location, textLength - 1)
            let range = textStorage.mutableString.paragraphRange(
                for: NSRange(location: location, length: 0)
            )
            currentLineRange = range
            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: syntaxPalette.currentLine.nsColor,
                forCharacterRange: range
            )
        } else {
            currentLineRange = nil
        }

        for range in matchingDelimiterRanges {
            removeTemporaryAttribute(
                .underlineStyle,
                forRange: range,
                layoutManager: layoutManager,
                textLength: textStorage.length
            )
            removeTemporaryAttribute(
                .underlineColor,
                forRange: range,
                layoutManager: layoutManager,
                textLength: textStorage.length
            )
        }
        matchingDelimiterRanges = matchingRanges(
            in: textStorage.string,
            at: textView.selectedRange().location
        )
        for range in matchingDelimiterRanges {
            layoutManager.addTemporaryAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                forCharacterRange: range
            )
            layoutManager.addTemporaryAttribute(
                .underlineColor,
                value: syntaxPalette.link.nsColor,
                forCharacterRange: range
            )
        }
    }

    private func removeTemporaryAttribute(
        _ key: NSAttributedString.Key,
        forRange range: NSRange,
        layoutManager: NSLayoutManager,
        textLength: Int
    ) {
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textLength)
        )
        guard safeRange.location != NSNotFound, safeRange.length > 0 else { return }
        layoutManager.removeTemporaryAttribute(key, forCharacterRange: safeRange)
    }

    private func matchingRanges(in text: String, at cursor: Int) -> [NSRange] {
        let value = text as NSString
        guard value.length > 0 else { return [] }
        let candidate = cursor < value.length ? cursor : cursor - 1
        guard candidate >= 0, candidate < value.length else { return [] }

        let pairs: [UInt16: UInt16] = [40: 41, 91: 93, 123: 125]
        let reverse: [UInt16: UInt16] = [41: 40, 93: 91, 125: 123]
        let character = value.character(at: candidate)
        if let closing = pairs[character] {
            var depth = 0
            for index in candidate..<value.length {
                let current = value.character(at: index)
                if current == character { depth += 1 }
                if current == closing {
                    depth -= 1
                    if depth == 0 {
                        return [
                            NSRange(location: candidate, length: 1),
                            NSRange(location: index, length: 1),
                        ]
                    }
                }
            }
        } else if let opening = reverse[character] {
            var depth = 0
            var index = candidate
            while index >= 0 {
                let current = value.character(at: index)
                if current == character { depth += 1 }
                if current == opening {
                    depth -= 1
                    if depth == 0 {
                        return [
                            NSRange(location: index, length: 1),
                            NSRange(location: candidate, length: 1),
                        ]
                    }
                }
                index -= 1
            }
        }
        return []
    }
}
