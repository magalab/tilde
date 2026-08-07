import QuickLookUI
import TildeCore
import UniformTypeIdentifiers

open class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    public func providePreview(
        for request: QLFilePreviewRequest,
        completionHandler handler: @escaping (QLPreviewReply?, (any Error)?) -> Void
    ) {
        let fileURL = request.fileURL
        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 900, height: 700)
        ) { reply in
            let rendered: RenderedQuickLookHTML
            do {
                let source = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                guard source.count <= MarkdownPolicy.default.maximumSourceBytes else {
                    throw QuickLookRenderError.sourceTooLarge
                }
                let decoded = try TextDecoder.decode(source)
                rendered = try QuickLookHTMLRenderer.render(
                    markdown: decoded.text,
                    documentURL: fileURL
                )
            } catch {
                rendered = QuickLookHTMLRenderer.fallback(message: error.localizedDescription)
            }

            reply.title = fileURL.lastPathComponent
            reply.stringEncoding = .utf8
            reply.attachments = Dictionary(
                uniqueKeysWithValues: rendered.attachments.compactMap { attachment in
                    guard let type = UTType(attachment.contentTypeIdentifier) else { return nil }
                    return (
                        attachment.identifier,
                        QLPreviewReplyAttachment(data: attachment.data, contentType: type)
                    )
                }
            )
            return rendered.data
        }
        handler(reply, nil)
    }
}
