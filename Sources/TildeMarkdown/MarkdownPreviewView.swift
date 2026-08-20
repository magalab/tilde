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
                    .textual.codeBlockStyle(CopyableCodeBlockStyle())
                    .textual.textSelection(.enabled)
                    .textual.imageAttachmentLoader(
                        MarkdownAttachmentLoader(
                            local: SecureAttachmentLoader(
                                documentURL: snapshot.fileURL,
                                policy: policy
                            ),
                            policy: policy
                        )
                    )
                    .id(policy.allowsRemoteResources)
                    .frame(maxWidth: 960, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollPosition($scrollPosition)
                .accessibilityLabel(L10n.string("Markdown preview"))
            } else if let errorMessage = model.errorMessage {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        L10n.string("Preview Unavailable"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(errorMessage)
                    )
                    Button(L10n.string("Retry Preview")) {
                        model.retry()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ProgressView(L10n.string("Rendering Markdown…"))
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(snapshot.revision)-\(model.retryToken)") {
            await model.render(snapshot: snapshot, policy: policy)
        }
    }
}

private struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let languageHint = configuration.languageHint,
                   !languageHint.isEmpty
                {
                    Text(languageHint)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    configuration.codeBlock.copyToPasteboard()
                } label: {
                    Label(L10n.string("Copy"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(L10n.string("Copy"))
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Overflow {
                configuration.label
                    .textual.lineSpacing(.fontScaled(0.225))
                    .textual.fontScale(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospaced()
                    .padding(16)
            }
        }
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .textual.blockSpacing(.init(top: 0, bottom: 16))
    }
}
