import SwiftUI
import TildeCore
import TildeDocument
import TildeEditor
import TildeMarkdown

@MainActor
struct DocumentRootView: View {
    @ObservedObject private var document: TextDocument
    @State private var session: EditorSession
    @State private var previewSnapshot: DocumentSnapshot?
    @State private var previewModel = MarkdownPreviewModel()
    @Bindable private var settings: EditorSettings

    init(document: TextDocument, settings: EditorSettings) {
        self.document = document
        self.settings = settings
        _session = State(initialValue: EditorSession())
        _previewSnapshot = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            if document.externalChangeState != .unchanged {
                externalChangeBanner
                Divider()
            }
            if document.largeFileDisposition != .standard {
                largeFileBanner
                Divider()
            }
            if document.metadata.documentType == TildeDocumentType.markdown {
                modeBar
                Divider()
            }
            content
            Divider()
            EditorStatusView(document: document, session: session)
        }
        .frame(minWidth: 520, minHeight: 360)
        .onExitCommand {
            if session.mode == .preview {
                session.mode = .edit
            }
        }
        .onChange(of: session.mode) { _, mode in
            if mode == .preview {
                if document.isMarkdownPreviewAllowed {
                    previewSnapshot = document.makeSnapshot()
                } else {
                    session.mode = .edit
                }
            }
        }
        .onChange(of: document.revision) { _, _ in
            if session.mode == .preview {
                if document.isMarkdownPreviewAllowed {
                    previewSnapshot = document.makeSnapshot()
                } else {
                    previewSnapshot = nil
                    session.mode = .edit
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .toggleMarkdownPreview,
                object: document
            )
        ) { _ in
            if session.mode == .preview {
                session.mode = .edit
            } else if document.isMarkdownPreviewAllowed {
                session.mode = .preview
            }
        }
    }

    private var externalChangeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: externalChangeIcon)
                .foregroundStyle(.orange)
            Text(externalChangeMessage)
                .font(.callout)
            Spacer()
            switch document.externalChangeState {
            case .conflict:
                Button(L10n.string("Keep Local")) {
                    document.keepLocalChangesAfterConflict()
                }
                Button(L10n.string("Reload")) {
                    reloadFromDisk()
                }
                .keyboardShortcut(.defaultAction)
                Button(L10n.string("Save As…")) {
                    document.saveAs(nil)
                }
            case .deletedOnDisk, .becameReadOnly:
                Button(L10n.string("Save As…")) {
                    document.saveAs(nil)
                }
                .keyboardShortcut(.defaultAction)
            case .changedOnDisk:
                Button(L10n.string("Try Again")) {
                    reloadFromDisk()
                }
                .keyboardShortcut(.defaultAction)
            case .unchanged:
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(.orange.opacity(0.08))
        .accessibilityElement(children: .contain)
    }

    private var externalChangeMessage: String {
        switch document.externalChangeState {
        case .unchanged:
            ""
        case .changedOnDisk:
            L10n.string("The file changed on disk but could not be reloaded.")
        case .deletedOnDisk:
            L10n.string("The file was deleted. The in-memory text is still available.")
        case .becameReadOnly:
            L10n.string("The file is now read-only.")
        case .conflict:
            L10n.string("The file changed on disk while this document had unsaved edits.")
        }
    }

    private var externalChangeIcon: String {
        switch document.externalChangeState {
        case .deletedOnDisk: "trash"
        case .becameReadOnly: "lock"
        default: "exclamationmark.triangle"
        }
    }

    private var largeFileBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("Large File Mode"))
                    .font(.callout.weight(.semibold))
                Text(largeFileMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(workingFileSizeLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(.orange.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.format(
                "Large File Mode. %@. %@",
                largeFileMessage,
                workingFileSizeLabel
            )
        )
    }

    private var largeFileMessage: String {
        switch document.largeFileDisposition {
        case .standard:
            ""
        case .largeFileMode:
            document.metadata.documentType == TildeDocumentType.markdown
                ? L10n.string("Markdown preview and word wrapping are disabled to preserve editing performance.")
                : L10n.string("Word wrapping is disabled to preserve editing performance.")
        case .exceedsValidatedLimit:
            L10n.string("This edited document now exceeds the validated 100 MB baseline; save and memory use may be high.")
        }
    }

    private var workingFileSizeLabel: String {
        let byteCount = max(document.metadata.sourceByteCount, document.workingUTF8ByteCount)
        return ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    private func reloadFromDisk() {
        Task {
            do {
                try await document.reloadFromDiskDiscardingLocalChanges()
            } catch {
                document.setExternalChangeState(.changedOnDisk)
                document.presentError(error)
            }
        }
    }

    private var modeBar: some View {
        @Bindable var session = session
        return HStack {
            if document.markdownPreviewAvailability == .sourceTooLarge {
                Label(L10n.string("Preview disabled over 5 MB"), systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(L10n.string("The measured Markdown safety ceiling is 5 MB."))
            }
            Spacer()
            Picker(L10n.string("Mode"), selection: $session.mode) {
                Text(L10n.string("Edit")).tag(DocumentViewMode.edit)
                Text(L10n.string("Preview"))
                    .tag(DocumentViewMode.preview)
                    .disabled(!document.isMarkdownPreviewAllowed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var session = session
        switch session.mode {
        case .edit:
            EditorView(document: document, session: session, settings: settings)
        case .preview:
            if let previewSnapshot {
                MarkdownPreviewView(
                    snapshot: previewSnapshot,
                    model: previewModel,
                    scrollPosition: $session.previewScrollPosition
                )
                .preferredColorScheme(previewColorScheme)
            } else {
                ProgressView()
                    .onAppear { previewSnapshot = document.makeSnapshot() }
            }
        }
    }

    private var previewColorScheme: ColorScheme? {
        switch settings.previewTheme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
