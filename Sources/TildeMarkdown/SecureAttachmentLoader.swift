import AppKit
import ImageIO
import SwiftUI
import Textual
import TildeCore
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

private actor AttachmentBudget {
    private var count = 0
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
}

struct SecureAttachmentLoader: AttachmentLoader {
    enum Blocked: Error {
        case resourceLoadingDisabled
        case resourceLimitExceeded
        case invalidImage
    }

    let documentDirectory: URL?
    let policy: MarkdownPolicy
    private let budget = AttachmentBudget()

    init(documentURL: URL?, policy: MarkdownPolicy) {
        documentDirectory = documentURL?.deletingLastPathComponent()
        self.policy = policy
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
        case "http", "https":
            guard policy.allowsRemoteResource(url) else {
                return .failure(L10n.string("Remote image loading is disabled."))
            }
            do {
                let image = try await RemoteImageAttachmentLoader(policy: policy).attachment(
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
    case failure(String)

    var description: String {
        switch self {
        case let .image(image): image.description
        case let .failure(message): message
        }
    }

    @MainActor
    var body: some View {
        switch self {
        case let .image(image): image.body
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
        case .failure: CGSize(width: min(proposal.width ?? 320, 480), height: 42)
        }
    }

    func pngData() -> Data? { nil }
}

private struct RemoteImageAttachmentLoader: AttachmentLoader {
    let policy: MarkdownPolicy

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
    }
}
