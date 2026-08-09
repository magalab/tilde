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
        configure(textView, coordinator: context.coordinator, settings: settings)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        context.coordinator.observeScrollView(scrollView)

        apply(settings, to: textView, in: scrollView)
        context.coordinator.refreshSyntaxHighlighting(
            in: textView,
            palette: settings.editorThemePalette
        )
        context.coordinator.refreshSelectionDecorations(in: textView)
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
        context.coordinator.refreshSyntaxHighlighting(
            in: textView,
            palette: settings.editorThemePalette
        )
        context.coordinator.refreshSelectionDecorations(in: textView)

        let maximumLocation = document.textStorage.length
        let requestedRanges = session.selectedRanges.filter {
            $0.location <= maximumLocation && $0.location + $0.length <= maximumLocation
        }
        if !requestedRanges.isEmpty {
            let currentRanges = textView.selectedRanges.map(\.rangeValue)
            if currentRanges != requestedRanges {
                textView.setSelectedRanges(
                    requestedRanges.map { NSValue(range: $0) },
                    affinity: .downstream,
                    stillSelecting: false
                )
            }
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

    private func configure(
        _ textView: EditorTextView,
        coordinator: EditorCoordinator,
        settings: EditorSettings
    ) {
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

        var smartZoomBaseFontSize: Double?
        textView.magnificationHandler = { [weak settings] magnification in
            guard let settings else { return }
            let scale = max(0.1, 1 + Double(magnification))
            settings.setFontSize(settings.fontSize * scale)
        }
        textView.smartMagnificationHandler = { [weak settings] in
            guard let settings else { return }
            if let baseFontSize = smartZoomBaseFontSize {
                smartZoomBaseFontSize = nil
                settings.setFontSize(baseFontSize)
            } else {
                smartZoomBaseFontSize = settings.fontSize
                settings.setFontSize(settings.fontSize * 1.5)
            }
        }
        textView.slashCommandHandler = { textView in
            let menu = NSMenu()
            for command in MarkdownSlashCommand.allCases {
                let item = menu.addItem(withTitle: "/\(command.rawValue) — \(command.title)", action: #selector(EditorTextView.applySlashCommand(_:)), keyEquivalent: "")
                item.target = textView
                item.representedObject = command.rawValue
            }
            let screenRect = textView.firstRect(
                forCharacterRange: textView.selectedRange(),
                actualRange: nil
            )
            guard !screenRect.isEmpty else { return }
            guard let window = textView.window else { return }
            let windowPoint = window.convertPoint(fromScreen: screenRect.origin)
            let viewPoint = textView.convert(windowPoint, from: nil)
            menu.popUp(positioning: nil, at: viewPoint, in: textView)
        }
    }

    private func apply(
        _ settings: EditorSettings,
        to textView: EditorTextView,
        in scrollView: NSScrollView
    ) {
        let wrap = settings.wordWrap && document.largeFileDisposition == .standard
        let palette = settings.editorThemePalette
        textView.indentStyle = settings.indentStyle
        textView.tabWidth = settings.tabWidth
        textView.markdownEditingEnabled = document.metadata.documentType == TildeDocumentType.markdown
        textView.isHorizontallyResizable = !wrap
        textView.autoresizingMask = wrap ? [.width] : []
        scrollView.hasHorizontalScroller = !wrap
        textView.textContainer?.widthTracksTextView = wrap
        textView.textContainer?.containerSize = NSSize(
            width: wrap ? max(0, scrollView.contentSize.width) : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let font = settings.font
        textView.backgroundColor = palette.background.nsColor
        textView.textColor = palette.foreground.nsColor
        textView.insertionPointColor = palette.foreground.nsColor
        textView.selectedTextAttributes = [
            .backgroundColor: palette.selection.nsColor,
            .foregroundColor: palette.foreground.nsColor,
        ]
        textView.font = font
        var typingAttributes = textView.typingAttributes
        typingAttributes[.font] = font
        typingAttributes[.ligature] = settings.fontLigatures ? 1 : 0
        textView.typingAttributes = typingAttributes

        configureLineNumbers(
            settings.showLineNumbers,
            font: font,
            palette: palette,
            textView: textView,
            scrollView: scrollView
        )

        if let layoutManager = textView.layoutManager,
           document.textStorage.length > 0
        {
            let fullRange = NSRange(location: 0, length: document.textStorage.length)
            textView.textStorage?.addAttribute(.font, value: font, range: fullRange)
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
            layoutManager.invalidateLayout(
                forCharacterRange: fullRange,
                actualCharacterRange: nil
            )
            layoutManager.invalidateDisplay(forCharacterRange: fullRange)
        }
        textView.needsLayout = true
        textView.needsDisplay = true
    }

    private func configureLineNumbers(
        _ visible: Bool,
        font: NSFont,
        palette: EditorThemePalette,
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
                document: document,
                palette: palette
            )
            scrollView.verticalRulerView = ruler
        }
        ruler.refresh(font: font, palette: palette)
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
    }
}
