import Foundation
import Observation
import Textual
import TildeCore
import TildeDocument

public enum MarkdownPreviewError: LocalizedError, Sendable {
    case sourceTooLarge
    case outputTooLarge
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sourceTooLarge:
            L10n.string("Markdown preview is disabled because this document exceeds the preview size limit.")
        case .outputTooLarge:
            L10n.string("Markdown preview exceeded its output budget.")
        case let .parsingFailed(message):
            L10n.format("Markdown could not be rendered: %@", message)
        }
    }
}

public struct PreparedMarkdown: @unchecked Sendable {
    public let attributedString: AttributedString
    public let revision: UInt64

    public init(attributedString: AttributedString, revision: UInt64) {
        self.attributedString = attributedString
        self.revision = revision
    }
}

@MainActor
@Observable
public final class MarkdownPreviewModel {
    public private(set) var prepared: PreparedMarkdown?
    public private(set) var isRendering = false
    public private(set) var errorMessage: String?
    public private(set) var retryToken = 0
    private var requestedRevision: UInt64?

    public init() {}

    public func render(
        snapshot: DocumentSnapshot,
        policy: MarkdownPolicy = .default
    ) async {
        let requestedRevision = snapshot.revision
        if prepared?.revision == requestedRevision {
            return
        }

        guard snapshot.utf8ByteCount <= policy.maximumSourceBytes else {
            prepared = nil
            errorMessage = MarkdownPreviewError.sourceTooLarge.localizedDescription
            return
        }

        isRendering = true
        self.requestedRevision = requestedRevision
        errorMessage = nil
        defer {
            if self.requestedRevision == requestedRevision {
                isRendering = false
            }
        }

        do {
            let parsed = try await MarkdownPreparser.prepare(
                snapshot: snapshot,
                policy: policy
            )
            try Task.checkCancellation()
            guard parsed.revision == requestedRevision,
                  self.requestedRevision == requestedRevision
            else { return }
            prepared = parsed
        } catch is CancellationError {
            return
        } catch {
            prepared = nil
            errorMessage = error.localizedDescription
        }
    }

    public func retry() {
        retryToken &+= 1
        prepared = nil
        errorMessage = nil
    }
}

private enum MarkdownPreparser {
    static func prepare(
        snapshot: DocumentSnapshot,
        policy: MarkdownPolicy
    ) async throws -> PreparedMarkdown {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            var attributed = try AttributedString(
                markdown: snapshot.text,
                including: \.textual,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                ),
                baseURL: snapshot.fileURL?.deletingLastPathComponent()
            )

            let blockedLinkRanges = attributed.runs.compactMap { run -> Range<AttributedString.Index>? in
                guard let link = run.link,
                      !policy.allowsLink(link.absoluteString)
                else { return nil }
                return run.range
            }
            for range in blockedLinkRanges {
                attributed[range].link = nil
            }

            guard String(attributed.characters).utf8.count <= policy.maximumOutputBytes else {
                throw MarkdownPreviewError.outputTooLarge
            }

            try Task.checkCancellation()
            return PreparedMarkdown(attributedString: attributed, revision: snapshot.revision)
        }.value
    }
}
