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
    private var renderGeneration: UInt64 = 0
    private let preparer: @Sendable (
        DocumentSnapshot,
        MarkdownPolicy
    ) async throws -> PreparedMarkdown

    public init() {
        preparer = MarkdownPreparser.prepare
    }

    init(
        preparer: @escaping @Sendable (
            DocumentSnapshot,
            MarkdownPolicy
        ) async throws -> PreparedMarkdown
    ) {
        self.preparer = preparer
    }

    /// Releases the parsed representation and invalidates any render that is still in flight.
    ///
    /// Preview views can live longer than the visible SwiftUI branch (for example, while a
    /// document remains in a native tab). Keeping this state bounded prevents every tab that has
    /// shown a preview from retaining its full attributed representation indefinitely.
    public func reset() {
        renderGeneration &+= 1
        isRendering = false
        prepared = nil
        errorMessage = nil
    }

    public func render(
        snapshot: DocumentSnapshot,
        policy: MarkdownPolicy = .default
    ) async {
        let revision = snapshot.revision
        if prepared?.revision == revision {
            return
        }

        renderGeneration &+= 1
        let generation = renderGeneration

        // Do not retain the previous document while the new one is being parsed. This avoids a
        // temporary double allocation when an editor is in split mode and changes frequently.
        prepared = nil

        guard snapshot.utf8ByteCount <= policy.maximumSourceBytes else {
            guard renderGeneration == generation else { return }
            isRendering = false
            errorMessage = MarkdownPreviewError.sourceTooLarge.localizedDescription
            return
        }

        isRendering = true
        errorMessage = nil
        defer {
            if self.renderGeneration == generation {
                isRendering = false
            }
        }

        do {
            let parsed = try await preparer(snapshot, policy)
            try Task.checkCancellation()
            guard parsed.revision == revision,
                  self.renderGeneration == generation
            else { return }
            prepared = parsed
        } catch is CancellationError {
            return
        } catch {
            guard renderGeneration == generation else { return }
            prepared = nil
            errorMessage = error.localizedDescription
        }
    }

    public func retry() {
        retryToken &+= 1
        reset()
    }
}

private enum MarkdownPreparser {
    static func prepare(
        snapshot: DocumentSnapshot,
        policy: MarkdownPolicy
    ) async throws -> PreparedMarkdown {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let parser = await AttributedStringMarkdownParser.markdown(
                baseURL: snapshot.fileURL?.deletingLastPathComponent(),
                syntaxExtensions: [.math]
            )
            var attributed = try await parser.attributedString(
                for: MarkdownSourcePreprocessor.prepareForAttributedString(snapshot.text)
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
