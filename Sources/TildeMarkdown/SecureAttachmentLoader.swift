import AppKit
import BeautifulMermaid
import CryptoKit
import ImageIO
import SwiftUI
import Textual
import TildeCore
import TildeImage
import UniformTypeIdentifiers

struct LocalImageAttachment: Attachment {
    let data: Data
    let description: String
    let pixelSize: CGSize

    @MainActor
    var body: some View {
        Group {
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text(description)
            }
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        in environment: TextEnvironmentValues
    ) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }
        let width = min(proposal.width ?? pixelSize.width, pixelSize.width)
        return CGSize(width: width, height: width * pixelSize.height / pixelSize.width)
    }

    func pngData() -> Data? { nil }
}

struct MermaidImageAttachment: Attachment {
    let data: Data
    let description: String
    let pixelSize: CGSize

    @MainActor
    var body: some View {
        Group {
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text(description)
            }
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        in _: TextEnvironmentValues
    ) -> CGSize {
        sizeThatFits(proposal)
    }

    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }
        let width = min(proposal.width ?? pixelSize.width, pixelSize.width)
        return CGSize(width: width, height: width * pixelSize.height / pixelSize.width)
    }

    func pngData() -> Data? { data }
}

private enum PreviewImageDecoder {
    // A 2K square is enough for a retina-sized Markdown preview while keeping decoded image
    // memory bounded. The source image is still validated against the policy before this cap is
    // applied.
    private static let maximumRenderedPixels = 4_000_000

    static func renderedData(
        from data: Data,
        source: CGImageSource,
        pixelWidth: Double,
        pixelHeight: Double
    ) throws -> (data: Data, pixelSize: CGSize) {
        guard pixelWidth * pixelHeight > Double(maximumRenderedPixels) else {
            return (
                data,
                CGSize(width: pixelWidth, height: pixelHeight)
            )
        }

        let maxPixelSize = Int(sqrt(Double(maximumRenderedPixels)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }

        return (
            output as Data,
            CGSize(width: image.width, height: image.height)
        )
    }
}

actor AttachmentBudget {
    private var count = 0
    private var mermaidCount = 0
    private var totalBytes = 0

    func reserve(bytes: Int, policy: MarkdownPolicy) -> Bool {
        guard count < policy.maximumAttachmentCount,
              bytes <= policy.maximumAttachmentBytes,
              totalBytes + bytes <= policy.maximumAttachmentBytes
        else { return false }
        count += 1
        totalBytes += bytes
        return true
    }

    func reserveMermaid(policy: MarkdownPolicy) -> Bool {
        guard count < policy.maximumAttachmentCount,
              mermaidCount < policy.maximumMermaidDiagramCount
        else { return false }
        count += 1
        mermaidCount += 1
        return true
    }

    func add(bytes: Int, policy: MarkdownPolicy) -> Bool {
        guard bytes <= policy.maximumAttachmentBytes,
              totalBytes + bytes <= policy.maximumAttachmentBytes
        else { return false }
        totalBytes += bytes
        return true
    }

    func release(bytes: Int = 0) {
        count = max(0, count - 1)
        totalBytes = max(0, totalBytes - bytes)
    }

    func releaseMermaid() {
        count = max(0, count - 1)
        mermaidCount = max(0, mermaidCount - 1)
    }
}

struct SecureAttachmentLoader: AttachmentLoader {
    enum Blocked: Error {
        case resourceLoadingDisabled
        case resourceLimitExceeded
        case invalidImage
    }

    let documentDirectory: URL?
    let policy: MarkdownPolicy
    fileprivate let budget: AttachmentBudget

    init(documentURL: URL?, policy: MarkdownPolicy) {
        self.init(documentURL: documentURL, policy: policy, budget: AttachmentBudget())
    }

    fileprivate init(documentURL: URL?, policy: MarkdownPolicy, budget: AttachmentBudget) {
        documentDirectory = documentURL?.deletingLastPathComponent()
        self.policy = policy
        self.budget = budget
    }

    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> LocalImageAttachment {
        guard let resolved = MarkdownResourceResolver.localResourceURL(
            for: url,
            documentDirectory: documentDirectory
        ),
        let values = try? resolved.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
        values.isRegularFile == true,
        let fileSize = values.fileSize,
        fileSize <= policy.maximumAttachmentBytes,
        let type = UTType(filenameExtension: resolved.pathExtension),
        type.conforms(to: .image)
        else { throw Blocked.resourceLoadingDisabled }

        let data = try Data(contentsOf: resolved, options: [.mappedIfSafe])
        guard await budget.reserve(bytes: data.count, policy: policy) else {
            throw Blocked.resourceLimitExceeded
        }
        do {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
                  let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
                  width > 0,
                  height > 0,
                  width * height <= Double(policy.maximumImagePixels)
            else { throw Blocked.invalidImage }

            let rendered = try PreviewImageDecoder.renderedData(
                from: data,
                source: source,
                pixelWidth: width,
                pixelHeight: height
            )
            return LocalImageAttachment(
                data: rendered.data,
                description: text,
                pixelSize: rendered.pixelSize
            )
        } catch {
            await budget.release(bytes: data.count)
            throw error
        }
    }
}

struct MarkdownAttachmentLoader: AttachmentLoader {
    let local: SecureAttachmentLoader
    let policy: MarkdownPolicy

    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> MarkdownImageAttachment {
        switch url.scheme?.lowercased() {
        case "mermaid":
            guard let source = MermaidSourceCodec.source(from: url),
                  source.utf8.count <= policy.maximumMermaidSourceBytes,
                  await local.budget.reserveMermaid(policy: policy)
            else {
                return .failure(L10n.string("Mermaid diagram is too large or exceeds the preview limit."))
            }
            do {
                let attachment = try await MermaidDiagramRenderer.render(
                    source: source,
                    text: text,
                    environment: environment,
                    policy: policy
                )
                guard await local.budget.add(bytes: attachment.data.count, policy: policy) else {
                    await local.budget.releaseMermaid()
                    return .failure(L10n.string("Mermaid diagram is too large or exceeds the preview limit."))
                }
                return .mermaid(attachment)
            } catch {
                await local.budget.releaseMermaid()
                return .failure(L10n.format("Mermaid diagram could not be rendered: %@", error.localizedDescription))
            }
        case "http", "https":
            guard policy.allowsRemoteResource(url) else {
                return .failure(L10n.string("Remote image loading is disabled."))
            }
            do {
                let image = try await RemoteImageAttachmentLoader(
                    policy: policy,
                    budget: local.budget
                ).attachment(
                    for: url,
                    text: text,
                    environment: environment
                )
                return .image(image)
            } catch {
                return .failure(L10n.string("Unable to load remote image."))
            }
        default:
            do {
                return .image(try await local.attachment(for: url, text: text, environment: environment))
            } catch {
                return .failure(L10n.string("Unable to load image."))
            }
        }
    }
}

enum MarkdownImageAttachment: Attachment {
    case image(LocalImageAttachment)
    case mermaid(MermaidImageAttachment)
    case failure(String)

    var description: String {
        switch self {
        case let .image(image): image.description
        case let .mermaid(image): image.description
        case let .failure(message): message
        }
    }

    @MainActor
    var body: some View {
        switch self {
        case let .image(image): image.body
        case let .mermaid(image): image.body
        case let .failure(message):
            Label(message, systemImage: "photo.badge.exclamationmark")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        in environment: TextEnvironmentValues
    ) -> CGSize {
        switch self {
        case let .image(image): image.sizeThatFits(proposal, in: environment)
        case let .mermaid(image): image.sizeThatFits(proposal, in: environment)
        case .failure: CGSize(width: min(proposal.width ?? 320, 480), height: 42)
        }
    }

    func pngData() -> Data? {
        switch self {
        case let .image(image): image.pngData()
        case let .mermaid(image): image.pngData()
        case .failure: nil
        }
    }
}

private enum MermaidDiagramRenderer {
    private static let cache = MermaidImageCache()
    private static let renderScale = 2.0

    static func render(
        source: String,
        text: String,
        environment: ColorEnvironmentValues,
        policy: MarkdownPolicy
    ) async throws -> MermaidImageAttachment {
        let theme: DiagramTheme = environment.colorScheme == .dark ? .githubDark : .githubLight
        let digest = SHA256.hash(data: Data(source.utf8))
        let cacheKey = "\(environment.colorScheme == .dark ? "dark" : "light"):"
            + digest.map { String(format: "%02x", $0) }.joined()
        if let cached = await cache.value(for: cacheKey) {
            guard policy.allowsMermaidImagePixels(
                width: cached.pixelSize.width,
                height: cached.pixelSize.height,
                scale: renderScale
            ),
            cached.data.count <= policy.maximumAttachmentBytes
            else {
                throw SecureAttachmentLoader.Blocked.invalidImage
            }
            return MermaidImageAttachment(
                data: cached.data,
                description: text,
                pixelSize: cached.pixelSize
            )
        }

        let positioned = try await Task.detached {
            try MermaidRenderer.layout(source)
        }.value
        guard policy.allowsMermaidImagePixels(
            width: positioned.width,
            height: positioned.height,
            scale: renderScale
        ) else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }

        let renderer = MermaidImageRenderer(theme: theme)
        renderer.scale = renderScale
        guard let renderedImage = renderer.renderImage(from: positioned, scale: renderScale) else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }
        guard let image = ImageTransform.verticallyFlipped(
            renderedImage,
            scale: renderScale
        ) else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }
        let logicalSize = image.size
        guard logicalSize.width > 0, logicalSize.height > 0,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]),
              bitmap.pixelsWide > 0,
              bitmap.pixelsHigh > 0,
              bitmap.pixelsWide * bitmap.pixelsHigh <= policy.maximumMermaidImagePixels,
              data.count <= policy.maximumAttachmentBytes
        else {
            throw SecureAttachmentLoader.Blocked.invalidImage
        }

        let attachment = MermaidImageAttachment(
            data: data,
            description: text,
            pixelSize: logicalSize
        )
        await cache.insert(attachment, for: cacheKey)
        return attachment
    }
}

private actor MermaidImageCache {
    private var values: [String: MermaidImageAttachment] = [:]
    private var insertionOrder: [String] = []
    private var totalBytes = 0
    private let maximumEntries = 8
    private let maximumBytes = 16 * 1_024 * 1_024

    func value(for key: String) -> MermaidImageAttachment? {
        values[key]
    }

    func insert(_ attachment: MermaidImageAttachment, for key: String) {
        guard attachment.data.count <= maximumBytes else { return }
        if let previous = values.updateValue(attachment, forKey: key) {
            totalBytes -= previous.data.count
            insertionOrder.removeAll { $0 == key }
        }
        totalBytes += attachment.data.count
        insertionOrder.append(key)

        while insertionOrder.count > maximumEntries || totalBytes > maximumBytes {
            guard let oldest = insertionOrder.first else { break }
            insertionOrder.removeFirst()
            if let removed = values.removeValue(forKey: oldest) {
                totalBytes -= removed.data.count
            }
        }
    }
}

private struct RemoteImageAttachmentLoader: AttachmentLoader {
    let policy: MarkdownPolicy
    let budget: AttachmentBudget

    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> LocalImageAttachment {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw SecureAttachmentLoader.Blocked.resourceLoadingDisabled
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode,
              let responseURL = response.url,
              ["http", "https"].contains(responseURL.scheme?.lowercased() ?? ""),
              let contentType = httpResponse.mimeType,
              let type = UTType(mimeType: contentType),
              type.conforms(to: .image)
        else {
            throw SecureAttachmentLoader.Blocked.resourceLoadingDisabled
        }

        var data = Data()
        data.reserveCapacity(min(policy.maximumAttachmentBytes, 1_024 * 1_024))
        for try await byte in bytes {
            guard data.count < policy.maximumAttachmentBytes else {
                throw SecureAttachmentLoader.Blocked.resourceLimitExceeded
            }
            data.append(byte)
        }

        guard await budget.reserve(bytes: data.count, policy: policy) else {
            throw SecureAttachmentLoader.Blocked.resourceLimitExceeded
        }
        do {
            guard !data.isEmpty,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
                  let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
                  width > 0,
                  height > 0,
                  width * height <= Double(policy.maximumImagePixels)
            else {
                throw SecureAttachmentLoader.Blocked.invalidImage
            }

            let rendered = try PreviewImageDecoder.renderedData(
                from: data,
                source: source,
                pixelWidth: width,
                pixelHeight: height
            )
            return LocalImageAttachment(
                data: rendered.data,
                description: text,
                pixelSize: rendered.pixelSize
            )
        } catch {
            await budget.release(bytes: data.count)
            throw error
        }
    }
}
