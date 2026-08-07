import AppKit
import SwiftUI
import TildeCore
import TildeDocument

public struct EditorView: NSViewRepresentable {
    public let document: TextDocument
    public let session: EditorSession
    @Bindable private var settings: EditorSettings

    public init(
        document: TextDocument,
        session: EditorSession,
        settings: EditorSettings
    ) {
        self.document = document
        self.session = session
        self.settings = settings
    }

    public func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(document: document, session: session)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        layoutManager.addTextContainer(textContainer)
        document.textStorage.addLayoutManager(layoutManager)

        let textView = EditorTextView(frame: .zero, textContainer: textContainer)
        configure(textView, coordinator: context.coordinator)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        context.coordinator.observeScrollView(scrollView)

        apply(settings, to: textView, in: scrollView)
        context.coordinator.refreshSyntaxHighlighting(in: textView)
        context.coordinator.presentationState = EditorPresentationState(settings: settings)
        DispatchQueue.main.async { [weak textView, weak scrollView] in
            if let scrollView {
                scrollView.contentView.scroll(to: session.scrollPosition)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            textView?.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }
        let presentationState = EditorPresentationState(settings: settings)
        if context.coordinator.presentationState != presentationState {
            apply(settings, to: textView, in: scrollView)
            context.coordinator.presentationState = presentationState
        }
        context.coordinator.refreshSyntaxHighlighting(in: textView)

        let maximumLocation = document.textStorage.length
        let requested = session.selection
        if requested.location <= maximumLocation,
           requested.location + requested.length <= maximumLocation,
           textView.selectedRange() != requested
        {
            textView.setSelectedRange(requested)
        }
    }

    public static func dismantleNSView(_ scrollView: NSScrollView, coordinator: EditorCoordinator) {
        guard let textView = scrollView.documentView as? NSTextView,
              let layoutManager = textView.layoutManager
        else { return }
        textView.delegate = nil
        coordinator.stopObservingScrollView()
        coordinator.stopSyntaxHighlighting()
        scrollView.rulersVisible = false
        scrollView.hasVerticalRuler = false
        scrollView.verticalRulerView = nil
        coordinator.document.textStorage.removeLayoutManager(layoutManager)
    }

    private func configure(_ textView: EditorTextView, coordinator: EditorCoordinator) {
        textView.delegate = coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.setAccessibilityIdentifier("Tilde.DocumentText")
        textView.setAccessibilityLabel(L10n.string("Document text editor"))
        textView.setAccessibilityHelp(L10n.string("Edit the plain-text contents of the current document."))
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
    }

    private func apply(
        _ settings: EditorSettings,
        to textView: EditorTextView,
        in scrollView: NSScrollView
    ) {
        let wrap = settings.wordWrap && document.largeFileDisposition == .standard
        textView.indentStyle = settings.indentStyle
        textView.tabWidth = settings.tabWidth
        textView.isHorizontallyResizable = !wrap
        textView.autoresizingMask = wrap ? [.width] : []
        scrollView.hasHorizontalScroller = !wrap
        textView.textContainer?.widthTracksTextView = wrap
        textView.textContainer?.containerSize = NSSize(
            width: wrap ? max(0, scrollView.contentSize.width) : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let font = settings.font
        var typingAttributes = textView.typingAttributes
        typingAttributes[.font] = font
        typingAttributes[.ligature] = settings.fontLigatures ? 1 : 0
        textView.typingAttributes = typingAttributes

        configureLineNumbers(
            settings.showLineNumbers,
            font: font,
            textView: textView,
            scrollView: scrollView
        )

        if let layoutManager = textView.layoutManager, document.textStorage.length > 0 {
            let fullRange = NSRange(location: 0, length: document.textStorage.length)
            layoutManager.removeTemporaryAttribute(.font, forCharacterRange: fullRange)
            layoutManager.addTemporaryAttribute(.font, value: font, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.ligature, forCharacterRange: fullRange)
            layoutManager.addTemporaryAttribute(
                .ligature,
                value: settings.fontLigatures ? 1 : 0,
                forCharacterRange: fullRange
            )

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.defaultTabInterval = (" " as NSString).size(withAttributes: [.font: font]).width
                * CGFloat(settings.tabWidth)
            layoutManager.removeTemporaryAttribute(.paragraphStyle, forCharacterRange: fullRange)
            layoutManager.addTemporaryAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                forCharacterRange: fullRange
            )
        }
    }

    private func configureLineNumbers(
        _ visible: Bool,
        font: NSFont,
        textView: NSTextView,
        scrollView: NSScrollView
    ) {
        guard visible else {
            scrollView.rulersVisible = false
            scrollView.hasVerticalRuler = false
            return
        }

        let ruler: LineNumberRulerView
        if let existing = scrollView.verticalRulerView as? LineNumberRulerView {
            ruler = existing
        } else {
            ruler = LineNumberRulerView(
                scrollView: scrollView,
                textView: textView,
                document: document
            )
            scrollView.verticalRulerView = ruler
        }
        ruler.refresh(font: font)
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
    }
}
