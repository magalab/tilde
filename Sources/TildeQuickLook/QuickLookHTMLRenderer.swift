import Foundation
import ImageIO
import Markdown
import TildeCore
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
        guard markdown.utf8.count <= policy.maximumSourceBytes else {
            throw QuickLookRenderError.sourceTooLarge
        }

        let document = Document(parsing: markdown)
        var formatter = SafeHTMLFormatter(
            policy: policy,
            documentDirectory: documentURL?.deletingLastPathComponent()
        )
        formatter.visit(document)

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
    private var inTableHead = false
    private var tableColumnAlignments: [Table.ColumnAlignment?]?
    private var currentTableColumn = 0

    init(policy: MarkdownPolicy, documentDirectory: URL?) {
        self.policy = policy
        self.documentDirectory = documentDirectory
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        result += "<blockquote>\n"
        descendInto(blockQuote)
        result += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let language = codeBlock.language.map {
            " class=\"language-\(HTMLEscaping.escape($0))\""
        } ?? ""
        result += "<pre><code\(language)>\(HTMLEscaping.escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        result += "<h\(heading.level)>"
        descendInto(heading)
        result += "</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        result += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        result += "<pre class=\"raw-html\">\(HTMLEscaping.escape(html.rawHTML))</pre>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        result += "<li>"
        if let checkbox = listItem.checkbox {
            result += checkbox == .checked
                ? "<input type=\"checkbox\" disabled checked> "
                : "<input type=\"checkbox\" disabled> "
        }
        descendInto(listItem)
        result += "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        result += "<ol\(start)>\n"
        descendInto(orderedList)
        result += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        result += "<ul>\n"
        descendInto(unorderedList)
        result += "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        result += "<p>"
        descendInto(paragraph)
        result += "</p>\n"
    }

    mutating func visitTable(_ table: Table) {
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
        result += HTMLEscaping.escape(text.string)
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
}
