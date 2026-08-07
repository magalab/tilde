import SwiftUI
import Textual
import TildeCore
import TildeDocument

@MainActor
private struct PreparedMarkupParser: MarkupParser {
    let prepared: AttributedString

    func attributedString(for input: String) throws -> AttributedString {
        prepared
    }
}

public struct MarkdownPreviewView: View {
    public let snapshot: DocumentSnapshot
    public let policy: MarkdownPolicy
    private let model: MarkdownPreviewModel
    @Binding private var scrollPosition: ScrollPosition

    public init(
        snapshot: DocumentSnapshot,
        policy: MarkdownPolicy = .default,
        model: MarkdownPreviewModel,
        scrollPosition: Binding<ScrollPosition>
    ) {
        self.snapshot = snapshot
        self.policy = policy
        self.model = model
        _scrollPosition = scrollPosition
    }

    public var body: some View {
        Group {
            if let prepared = model.prepared, prepared.revision == snapshot.revision {
                ScrollView {
                    StructuredText(
                        "",
                        parser: PreparedMarkupParser(prepared: prepared.attributedString)
                    )
                    .textual.structuredTextStyle(.gitHub)
                    .textual.textSelection(.enabled)
                    .textual.imageAttachmentLoader(
                        SecureAttachmentLoader(documentURL: snapshot.fileURL, policy: policy)
                    )
                    .frame(maxWidth: 860, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollPosition($scrollPosition)
                .accessibilityLabel(L10n.string("Markdown preview"))
            } else if let errorMessage = model.errorMessage {
                ContentUnavailableView(
                    L10n.string("Preview Unavailable"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView(L10n.string("Rendering Markdown…"))
                    .controlSize(.small)
            }
        }
        .task(id: snapshot.revision) {
            await model.render(snapshot: snapshot, policy: policy)
        }
    }
}
