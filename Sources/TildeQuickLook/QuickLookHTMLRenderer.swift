import Foundation
import AppKit
import BeautifulMermaid
import ImageIO
import Markdown
import TildeCore
import TildeImage
import UniformTypeIdentifiers

public struct QuickLookAttachment: Equatable, Sendable {
    public let identifier: String
    public let data: Data
    public let contentTypeIdentifier: String

    public init(identifier: String, data: Data, contentTypeIdentifier: String) {
        self.identifier = identifier
        self.data = data
        self.contentTypeIdentifier = contentTypeIdentifier
    }
}

public struct RenderedQuickLookHTML: Equatable, Sendable {
    public let data: Data
    public let attachments: [QuickLookAttachment]

    public init(data: Data, attachments: [QuickLookAttachment]) {
        self.data = data
        self.attachments = attachments
    }
}

public enum QuickLookRenderError: LocalizedError, Equatable, Sendable {
    case sourceTooLarge
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .sourceTooLarge:
            L10n.string("This Markdown file is too large to preview safely.")
        case .outputTooLarge:
            L10n.string("The generated Markdown preview exceeded its output limit.")
        }
    }
}

public enum QuickLookHTMLRenderer {
    public static func render(
        markdown: String,
        documentURL: URL? = nil,
        policy: MarkdownPolicy = .default
    ) throws -> RenderedQuickLookHTML {
        // This guard limits the complete untrusted Markdown source before parsing.
        guard markdown.utf8.count <= policy.maximumSourceBytes else {
            throw QuickLookRenderError.sourceTooLarge
        }

        return try render(
            document: Document(parsing: markdown),
            documentURL: documentURL,
            policy: policy
        )
    }

    static func render(
        document: Document,
        documentURL: URL? = nil,
        policy: MarkdownPolicy = .default
    ) throws -> RenderedQuickLookHTML {
        var formatter = SafeHTMLFormatter(
            policy: policy,
            documentDirectory: documentURL?.deletingLastPathComponent()
        )
        formatter.visit(document)
        formatter.finish()

        let html = htmlDocument(body: formatter.result)
        let data = Data(html.utf8)
        guard data.count <= policy.maximumOutputBytes else {
            throw QuickLookRenderError.outputTooLarge
        }
        return RenderedQuickLookHTML(data: data, attachments: formatter.attachments)
    }

    public static func fallback(message: String) -> RenderedQuickLookHTML {
        let body = "<p class=\"fallback\">\(HTMLEscaping.escape(message))</p>"
        return RenderedQuickLookHTML(data: Data(htmlDocument(body: body).utf8), attachments: [])
    }

    private static func htmlDocument(body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src cid:; style-src 'unsafe-inline'">
          <style>
            :root { color-scheme: light dark; }
            body {
              max-width: 860px; margin: 0 auto; padding: 28px 32px 48px;
              font: 15px/1.55 -apple-system, BlinkMacSystemFont, sans-serif;
              color: CanvasText; background: Canvas;
            }
            h1, h2 { border-bottom: 1px solid color-mix(in srgb, CanvasText 18%, transparent); padding-bottom: .25em; }
            pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
            code { background: color-mix(in srgb, CanvasText 9%, transparent); border-radius: 4px; padding: .12em .28em; }
            pre { overflow: auto; padding: 14px; border-radius: 7px; background: color-mix(in srgb, CanvasText 8%, transparent); }
            pre code { padding: 0; background: transparent; }
            blockquote { margin-left: 0; padding-left: 1em; border-left: 4px solid color-mix(in srgb, CanvasText 25%, transparent); color: color-mix(in srgb, CanvasText 72%, transparent); }
            ul, ol { padding-left: 1.5em; }
            li > p { margin: 0; }
            li + li { margin-top: .25em; }
            input:disabled { vertical-align: -1px; }
            .math-inline { white-space: nowrap; }
            .math-block { display: block; margin: 1em 0; overflow-x: auto; text-align: center; }
            math { font-family: "Latin Modern Math", "STIX Two Math", "Cambria Math", "STIX", serif; font-size: 1.08em; }
            .task-marker { display: inline-block; margin-bottom: .25em; }
            table { border-collapse: collapse; max-width: 100%; }
            th, td { border: 1px solid color-mix(in srgb, CanvasText 20%, transparent); padding: 6px 10px; }
            img { max-width: 100%; height: auto; }
            a { color: LinkText; }
            .blocked-image, .fallback, .raw-html { color: color-mix(in srgb, CanvasText 65%, transparent); }
          </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }
}

private struct SafeHTMLFormatter: MarkupWalker {
    private(set) var result = ""
    private(set) var attachments: [QuickLookAttachment] = []

    let policy: MarkdownPolicy
    let documentDirectory: URL?
    private var totalAttachmentBytes = 0
    private var mermaidCount = 0
    private var inTableHead = false
    private var tableColumnAlignments: [Table.ColumnAlignment?]?
    private var currentTableColumn = 0
    private var taskCheckboxes: [TaskCheckboxState] = []
    private var pendingMathDelimiter: String?
    private var pendingMathSource = ""

    init(policy: MarkdownPolicy, documentDirectory: URL?) {
        self.policy = policy
        self.documentDirectory = documentDirectory
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        emitPendingTaskCheckboxBeforeBlock()
        result += "<blockquote>\n"
        descendInto(blockQuote)
        result += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        emitPendingTaskCheckboxBeforeBlock()
        if codeBlock.language?.lowercased() == "mermaid",
           appendMermaidAttachment(code: codeBlock.code)
        {
            return
        }

        let language = codeBlock.language.map {
            " class=\"language-\(HTMLEscaping.escape($0))\""
        } ?? ""
        result += "<pre><code\(language)>\(HTMLEscaping.escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        emitPendingTaskCheckboxBeforeBlock()
        result += "<h\(heading.level)>"
        descendInto(heading)
        result += "</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        emitPendingTaskCheckboxBeforeBlock()
        result += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        emitPendingTaskCheckboxBeforeBlock()
        result += "<pre class=\"raw-html\">\(HTMLEscaping.escape(html.rawHTML))</pre>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        result += "<li>"
        taskCheckboxes.append(TaskCheckboxState(checkbox: listItem.checkbox))
        descendInto(listItem)
        taskCheckboxes.removeLast()
        result += "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        emitPendingTaskCheckboxBeforeBlock()
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        result += "<ol\(start)>\n"
        descendInto(orderedList)
        result += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        emitPendingTaskCheckboxBeforeBlock()
        result += "<ul>\n"
        descendInto(unorderedList)
        result += "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        result += "<p>"
        emitPendingTaskCheckbox(inParagraph: true)
        descendInto(paragraph)
        result += "</p>\n"
    }

    mutating func visitTable(_ table: Table) {
        emitPendingTaskCheckboxBeforeBlock()
        result += "<table>\n"
        tableColumnAlignments = table.columnAlignments
        descendInto(table)
        tableColumnAlignments = nil
        result += "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) {
        result += "<thead><tr>\n"
        inTableHead = true
        currentTableColumn = 0
        descendInto(tableHead)
        inTableHead = false
        result += "</tr></thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) {
        guard !tableBody.isEmpty else { return }
        result += "<tbody>\n"
        descendInto(tableBody)
        result += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        result += "<tr>\n"
        currentTableColumn = 0
        descendInto(tableRow)
        result += "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        let element = inTableHead ? "th" : "td"
        var attributes = ""
        if let alignments = tableColumnAlignments,
           currentTableColumn < alignments.count,
           let alignment = alignments[currentTableColumn]
        {
            attributes += " align=\"\(alignment)\""
        }
        currentTableColumn += 1
        if tableCell.rowspan > 1 { attributes += " rowspan=\"\(tableCell.rowspan)\"" }
        if tableCell.colspan > 1 { attributes += " colspan=\"\(tableCell.colspan)\"" }
        result += "<\(element)\(attributes)>"
        descendInto(tableCell)
        result += "</\(element)>\n"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        result += "<code>\(HTMLEscaping.escape(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        inline(tag: "em", content: emphasis)
    }

    mutating func visitStrong(_ strong: Strong) {
        inline(tag: "strong", content: strong)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        inline(tag: "del", content: strikethrough)
    }

    mutating func visitImage(_ image: Image) {
        let alt = image.plainText
        guard let source = image.source,
              let attachment = loadAttachment(source: source)
        else {
            result += "<span class=\"blocked-image\">[Image: \(HTMLEscaping.escape(alt))]</span>"
            return
        }

        attachments.append(attachment)
        let title = image.title.map { " title=\"\(HTMLEscaping.escape($0))\"" } ?? ""
        result += "<img src=\"cid:\(attachment.identifier)\" alt=\"\(HTMLEscaping.escape(alt))\"\(title)>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        result += HTMLEscaping.escape(inlineHTML.rawHTML)
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        result += "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        result += "\n"
    }

    mutating func visitLink(_ link: Link) {
        guard let destination = link.destination,
              policy.allowsLink(destination)
        else {
            descendInto(link)
            return
        }
        result += "<a href=\"\(HTMLEscaping.escape(destination))\">"
        descendInto(link)
        result += "</a>"
    }

    mutating func visitText(_ text: Text) {
        appendText(text.string)
    }

    mutating func finish() {
        guard let pendingMathDelimiter else { return }
        result += HTMLEscaping.escape(pendingMathDelimiter + pendingMathSource)
        self.pendingMathDelimiter = nil
        pendingMathSource = ""
    }

    private mutating func appendText(_ source: String) {
        var remainder = source
        while !remainder.isEmpty {
            if let delimiter = pendingMathDelimiter {
                guard let closing = remainder.range(of: delimiter) else {
                    appendPendingMathSource(remainder)
                    return
                }

                pendingMathSource += remainder[..<closing.lowerBound]
                result += QuickLookMathHTML.render(
                    pendingMathSource,
                    isBlock: delimiter == "$$"
                )
                pendingMathDelimiter = nil
                pendingMathSource = ""
                remainder = String(remainder[closing.upperBound...])
                continue
            }

            // A bare delimiter is rare, but supports a paragraph containing only "$$" or "$".
            if remainder == "$$" || remainder == "$" {
                pendingMathDelimiter = remainder
                return
            }
            result += QuickLookMathHTML.format(remainder)
            return
        }
    }

    private mutating func appendPendingMathSource(_ source: String) {
        // This limit protects only the cross-Text-node accumulator; the complete source
        // is bounded by the guard in render(markdown:).
        guard let delimiter = pendingMathDelimiter else { return }
        let currentBytes = pendingMathSource.utf8.count
        guard currentBytes <= policy.maximumSourceBytes,
              source.utf8.count <= policy.maximumSourceBytes - currentBytes
        else {
            result += HTMLEscaping.escape(delimiter + pendingMathSource)
            pendingMathDelimiter = nil
            pendingMathSource = ""
            result += QuickLookMathHTML.format(source)
            return
        }
        pendingMathSource += source
    }

    private mutating func emitPendingTaskCheckboxBeforeBlock() {
        emitPendingTaskCheckbox(inParagraph: false)
    }

    private mutating func emitPendingTaskCheckbox(inParagraph: Bool) {
        guard let index = taskCheckboxes.indices.last,
              let checkbox = taskCheckboxes[index].checkbox,
              !taskCheckboxes[index].wasEmitted
        else { return }

        let input = checkbox == .checked
            ? "<input type=\"checkbox\" disabled checked>"
            : "<input type=\"checkbox\" disabled>"
        if inParagraph {
            result += "\(input) "
        } else {
            result += "<span class=\"task-marker\">\(input)</span>\n"
        }
        taskCheckboxes[index].wasEmitted = true
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        if let destination = symbolLink.destination {
            result += "<code>\(HTMLEscaping.escape(destination))</code>"
        }
    }

    private mutating func inline(tag: String, content: Markup) {
        result += "<\(tag)>"
        descendInto(content)
        result += "</\(tag)>"
    }

    private mutating func loadAttachment(source: String) -> QuickLookAttachment? {
        guard attachments.count < policy.maximumAttachmentCount,
              let resolved = MarkdownResourceResolver.localResourceURL(
                for: source,
                documentDirectory: documentDirectory
              )
        else { return nil }

        guard let values = try? resolved.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true,
              let size = values.fileSize,
              size <= policy.maximumAttachmentBytes,
              totalAttachmentBytes + size <= policy.maximumAttachmentBytes,
              let contentType = UTType(filenameExtension: resolved.pathExtension),
              contentType.conforms(to: .image),
              let data = try? Data(contentsOf: resolved, options: [.mappedIfSafe]),
              data.count <= policy.maximumAttachmentBytes,
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0,
              width <= policy.maximumImagePixels,
              height <= policy.maximumImagePixels,
              width * height <= policy.maximumImagePixels
        else { return nil }

        totalAttachmentBytes += data.count
        return QuickLookAttachment(
            identifier: "asset-\(attachments.count)",
            data: data,
            contentTypeIdentifier: contentType.identifier
        )
    }

    private mutating func appendMermaidAttachment(code: String) -> Bool {
        let renderer = MermaidImageRenderer(theme: .githubLight)
        guard mermaidCount < policy.maximumMermaidDiagramCount,
              code.utf8.count <= policy.maximumMermaidSourceBytes,
              let positioned = try? MermaidRenderer.layout(code),
              policy.allowsMermaidImagePixels(
                  width: positioned.width,
                  height: positioned.height,
                  scale: Double(renderer.scale)
              ),
              let renderedImage = renderer.renderImage(from: positioned, scale: renderer.scale),
              let flippedImage = ImageTransform.verticallyFlipped(
                  renderedImage,
                  scale: renderer.scale
              ),
              let tiffData = flippedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]),
              data.count <= policy.maximumAttachmentBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0,
              width * height <= policy.maximumMermaidImagePixels,
              attachments.count < policy.maximumAttachmentCount,
              totalAttachmentBytes + data.count <= policy.maximumAttachmentBytes
        else { return false }

        let identifier = "mermaid-\(attachments.count)"
        attachments.append(
            QuickLookAttachment(
                identifier: identifier,
                data: data,
                contentTypeIdentifier: UTType.png.identifier
            )
        )
        totalAttachmentBytes += data.count
        mermaidCount += 1
        result += "<p class=\"mermaid\"><img src=\"cid:\(identifier)\" alt=\"Mermaid diagram\"></p>\n"
        return true
    }
}

private struct TaskCheckboxState {
    let checkbox: Checkbox?
    var wasEmitted = false
}

private enum QuickLookMathHTML {
    static func render(_ latex: String, isBlock: Bool) -> String {
        let markup = LatexMathMarkup.render(latex)
        if isBlock {
            return "<span class=\"math-block\"><math display=\"block\">\(markup)</math></span>"
        }
        return "<span class=\"math-inline\"><math>\(markup)</math></span>"
    }

    static func format(_ source: String) -> String {
        // Parse only this Text node. The complete source-size limit is enforced above.
        var output = ""
        var cursor = source.startIndex

        while cursor < source.endIndex {
            let delimiter: String
            let isBlock: Bool
            if source[cursor...].hasPrefix("$$") {
                delimiter = "$$"
                isBlock = true
            } else if source[cursor] == "$",
                      !isCurrencyStart(in: source, at: cursor)
            {
                delimiter = "$"
                isBlock = false
            } else {
                let next = source.index(after: cursor)
                output += HTMLEscaping.escape(String(source[cursor..<next]))
                cursor = next
                continue
            }

            let contentStart = source.index(cursor, offsetBy: delimiter.count)
            guard let closing = source.range(of: delimiter, range: contentStart..<source.endIndex) else {
                output += HTMLEscaping.escape(String(source[cursor...]))
                break
            }

            let latex = String(source[contentStart..<closing.lowerBound])
            output += render(latex, isBlock: isBlock)
            cursor = closing.upperBound
        }

        return output
    }

    private static func isCurrencyStart(in source: String, at index: String.Index) -> Bool {
        let next = source.index(after: index)
        guard next < source.endIndex else { return false }
        if source[next].isNumber { return true }
        guard source[next] == "." || source[next] == "," else { return false }
        let digit = source.index(after: next)
        return digit < source.endIndex && source[digit].isNumber
    }
}

private enum LatexMathMarkup {
    // This is intentionally a small, safe subset for Quick Look previews rather than
    // a complete LaTeX implementation. Unsupported commands are rendered as escaped
    // MathML identifiers so the surrounding document remains intact. Known limitations
    // include optional root indices (\\sqrt[3]{x}), nested matrices, and text commands
    // such as \\text{...}.
    static func render(_ latex: String) -> String {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        if let matrix = matrixMarkup(for: trimmed) {
            return matrix
        }

        var parser = Parser(Array(trimmed))
        return parser.sequence()
    }

    private static func matrixMarkup(for latex: String) -> String? {
        guard let begin = latex.range(of: "\\begin{bmatrix}"),
              let end = latex.range(of: "\\end{bmatrix}", range: begin.upperBound..<latex.endIndex)
        else { return nil }

        var prefixParser = Parser(Array(latex[..<begin.lowerBound]))
        let prefix = prefixParser.sequence()
        let body = latex[begin.upperBound..<end.lowerBound]
        let rows = body.components(separatedBy: "\\\\")
        var table = "<mtable>"
        for row in rows {
            let cells = row.split(separator: "&", omittingEmptySubsequences: false)
            table += "<mtr>"
            for cell in cells {
                table += "<mtd>\(render(String(cell)))</mtd>"
            }
            table += "</mtr>"
        }
        table += "</mtable>"
        let suffix = String(latex[end.upperBound...])
        return "\(prefix)<mfenced open=\"[\" close=\"]\">\(table)</mfenced>\(render(suffix))"
    }

    private struct Parser {
        let characters: [Character]
        var index = 0

        init(_ characters: [Character]) {
            self.characters = characters
        }

        mutating func sequence(until closing: Character? = nil) -> String {
            var output = ""
            while index < characters.count {
                if let closing, characters[index] == closing {
                    index += 1
                    break
                }
                if characters[index].isWhitespace {
                    index += 1
                    continue
                }

                var atom = atom()
                var subscriptMarkup: String?
                var superscriptMarkup: String?
                while index < characters.count, characters[index] == "_" || characters[index] == "^" {
                    let marker = characters[index]
                    index += 1
                    let argument = self.argument()
                    if marker == "_" { subscriptMarkup = argument }
                    else { superscriptMarkup = argument }
                }

                if let subscriptMarkup, let superscriptMarkup {
                    atom = "<msubsup>\(atom)\(subscriptMarkup)\(superscriptMarkup)</msubsup>"
                } else if let subscriptMarkup {
                    atom = "<msub>\(atom)\(subscriptMarkup)</msub>"
                } else if let superscriptMarkup {
                    atom = "<msup>\(atom)\(superscriptMarkup)</msup>"
                }
                output += atom
            }
            return output
        }

        private mutating func atom() -> String {
            let character = characters[index]
            index += 1

            if character == "{" {
                return "<mrow>\(sequence(until: "}"))</mrow>"
            }
            if character == "\\" {
                return command()
            }
            if character.isNumber {
                var value = String(character)
                while index < characters.count, characters[index].isNumber || characters[index] == "." {
                    value.append(characters[index])
                    index += 1
                }
                return "<mn>\(HTMLEscaping.escape(value))</mn>"
            }
            if character.isLetter {
                return "<mi>\(HTMLEscaping.escape(String(character)))</mi>"
            }

            let escaped = HTMLEscaping.escape(String(character))
            return "<mo>\(escaped)</mo>"
        }

        private mutating func command() -> String {
            guard index < characters.count else { return "<mo>\\</mo>" }
            if !characters[index].isLetter {
                let command = characters[index]
                index += 1
                switch command {
                case ",": return "<mspace width=\"0.2em\"/>"
                case ";": return "<mspace width=\"0.4em\"/>"
                case "\\": return "<mspace linebreak=\"newline\"/>"
                default: return "<mo>\(HTMLEscaping.escape(String(command)))</mo>"
                }
            }

            let start = index
            while index < characters.count, characters[index].isLetter {
                index += 1
            }
            let name = String(characters[start..<index])
            switch name {
            case "frac":
                return "<mfrac>\(argument())\(argument())</mfrac>"
            case "sqrt":
                return "<msqrt>\(argument())</msqrt>"
            case "bar":
                return "<mover accent=\"true\">\(argument())<mo>¯</mo></mover>"
            case "qquad":
                return "<mspace width=\"2em\"/>"
            case "quad":
                return "<mspace width=\"1em\"/>"
            case "pi": return "<mi>π</mi>"
            case "Delta": return "<mi>Δ</mi>"
            case "infty": return "<mo>∞</mo>"
            case "int": return "<mo>∫</mo>"
            case "sum": return "<mo>∑</mo>"
            case "cdot": return "<mo>⋅</mo>"
            case "mid": return "<mo>∣</mo>"
            case "to": return "<mo>→</mo>"
            case "le": return "<mo>≤</mo>"
            case "ge": return "<mo>≥</mo>"
            default:
                return "<mi>\(HTMLEscaping.escape(name))</mi>"
            }
        }

        private mutating func argument() -> String {
            guard index < characters.count else { return "<mrow></mrow>" }
            if characters[index] == "{" {
                index += 1
                return "<mrow>\(sequence(until: "}"))</mrow>"
            }
            return atom()
        }
    }
}
