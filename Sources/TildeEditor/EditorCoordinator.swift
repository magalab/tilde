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

    func refreshSyntaxHighlighting(in textView: NSTextView, edit: TextEdit? = nil) {
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
                textStorage: document.textStorage
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
            refreshSyntaxHighlighting(in: textView, edit: appliedEdit)
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?
                .invalidateLineNumbers()
        }
        updateSelection(from: textView)
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
        updateSelection(from: notification.object as? NSTextView)
    }

    private func updateSelection(from textView: NSTextView?) {
        guard let textView else { return }
        let selection = textView.selectedRange()
        session.selection = selection
        session.textPosition = document.lineIndex.position(
            forUTF16Offset: selection.location,
            in: document.textStorage.mutableString
        )
    }
}
