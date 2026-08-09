import AppKit
import TildeCore
import TildeDocument

@MainActor
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private weak var document: TextDocument?
    private var labelFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    private var palette = EditorThemePalette.light

    init(
        scrollView: NSScrollView,
        textView: NSTextView,
        document: TextDocument,
        palette: EditorThemePalette
    ) {
        self.textView = textView
        self.document = document
        self.palette = palette
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        setAccessibilityElement(true)
        setAccessibilityLabel(L10n.string("Line numbers"))
        refresh(
            font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            palette: palette
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func refresh(font: NSFont, palette: EditorThemePalette) {
        self.palette = palette
        labelFont = NSFont.monospacedDigitSystemFont(
            ofSize: max(10, font.pointSize * 0.82),
            weight: .regular
        )
        let lineCount = document?.lineIndex.lineCount ?? 1
        ruleThickness = Self.requiredThickness(forLineCount: lineCount, font: labelFont)
        needsDisplay = true
    }

    func invalidateLineNumbers() {
        guard let document else { return }
        let thickness = Self.requiredThickness(
            forLineCount: document.lineIndex.lineCount,
            font: labelFont
        )
        if ruleThickness != thickness {
            ruleThickness = thickness
        }
        needsDisplay = true
    }

    static func requiredThickness(forLineCount lineCount: Int, font: NSFont) -> CGFloat {
        let digits = String(max(1, lineCount))
        let width = (digits as NSString).size(withAttributes: [.font: font]).width
        return max(36, ceil(width) + 14)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        palette.background.nsColor.setFill()
        bounds.fill()

        guard let textView,
              let document,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView
        else { return }

        let visibleTextRect = scrollView.contentView.bounds
        let textOrigin = textView.textContainerOrigin
        let visibleContainerRect = visibleTextRect.offsetBy(
            dx: -textOrigin.x,
            dy: -textOrigin.y
        )
        let string = textView.string as NSString
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleContainerRect,
            in: textContainer
        )

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
            [weak self] lineRect, _, _, fragmentGlyphRange, _ in
            guard let self else { return }
            let characterRange = layoutManager.characterRange(
                forGlyphRange: fragmentGlyphRange,
                actualGlyphRange: nil
            )
            let location = characterRange.location
            let isLogicalLineStart = location == 0
                || (location <= string.length && string.character(at: location - 1) == 0x0A)
            guard isLogicalLineStart else { return }

            let line = document.lineIndex.position(
                forUTF16Offset: location,
                in: document.textStorage.mutableString
            ).line
            self.draw(lineNumber: line, textY: lineRect.minY + textOrigin.y, height: lineRect.height)
        }

        if string.length == 0 || string.character(at: string.length - 1) == 0x0A {
            let extraRect = layoutManager.extraLineFragmentRect
            if !extraRect.isEmpty {
                draw(
                    lineNumber: document.lineIndex.lineCount,
                    textY: extraRect.minY + textOrigin.y,
                    height: extraRect.height
                )
            }
        }

        palette.divider.nsColor.setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        divider.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        divider.stroke()
    }

    private func draw(lineNumber: Int, textY: CGFloat, height: CGFloat) {
        guard let textView else { return }
        let rulerPoint = convert(NSPoint(x: 0, y: textY), from: textView)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: palette.lineNumber.nsColor,
            .paragraphStyle: paragraph,
        ]
        let labelHeight = labelFont.ascender - labelFont.descender
        let labelRect = NSRect(
            x: 4,
            y: rulerPoint.y + max(0, (height - labelHeight) / 2),
            width: max(0, bounds.width - 10),
            height: max(height, labelHeight)
        )
        String(lineNumber).draw(in: labelRect, withAttributes: attributes)
    }
}
