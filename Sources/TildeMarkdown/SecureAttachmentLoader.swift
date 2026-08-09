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

        return LocalImageAttachment(
            data: data,
            description: text,
            pixelSize: CGSize(width: width, height: height)
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
    ) async throws -> LocalImageAttachment {
        switch url.scheme?.lowercased() {
        case "http", "https":
            guard policy.allowsRemoteResource(url) else {
                throw SecureAttachmentLoader.Blocked.resourceLoadingDisabled
            }
            return try await RemoteImageAttachmentLoader(policy: policy).attachment(
                for: url,
                text: text,
                environment: environment
            )
        default:
            return try await local.attachment(for: url, text: text, environment: environment)
        }
    }
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

        return LocalImageAttachment(
            data: data,
            description: text,
            pixelSize: CGSize(width: width, height: height)
        )
    }
}
