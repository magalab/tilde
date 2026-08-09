import SwiftUI
import TildeCore
import TildeDocument

public struct EditorStatusView: View {
    @ObservedObject private var document: TextDocument
    private let session: EditorSession
    @Bindable private var settings: EditorSettings

    public init(document: TextDocument, session: EditorSession, settings: EditorSettings) {
        self.document = document
        self.session = session
        self.settings = settings
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(L10n.format("Ln %d, Col %d", session.textPosition.line, session.textPosition.column))
            Text(fileSizeLabel)
                .monospacedDigit()
            if document.isDocumentEdited {
                Image(systemName: "pencil")
                    .help(L10n.string("Unsaved Changes"))
            }
            if document.externalChangeState != .unchanged {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(L10n.string("External Change"))
            }
            Spacer()
            encodingMenu
            lineEndingMenu
            indentMenu
            tabWidthMenu
            if document.largeFileDisposition != .standard {
                Text(L10n.string("Large File"))
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusAccessibilityLabel)
        .accessibilityIdentifier("editor.status-bar")
    }

    private var encodingMenu: some View {
        Menu {
            ForEach(TextEncoding.allCases, id: \.self) { encoding in
                Button {
                    document.changeEncoding(to: detectedEncoding(for: encoding))
                } label: {
                    Label {
                        Text(encoding.localizedName)
                    } icon: {
                        if document.metadata.encoding.encoding == encoding {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(document.metadata.encoding.encoding.localizedName)
                .monospaced()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L10n.string("Encoding"))
        .accessibilityLabel(L10n.format("Encoding: %@", document.metadata.encoding.encoding.localizedName))
        .accessibilityIdentifier("editor.status.encoding")
        .disabled(!document.canModifyDocumentSettings)
    }

    private var lineEndingMenu: some View {
        Menu {
            ForEach(LineEnding.allCases, id: \.self) { lineEnding in
                Button {
                    document.changeLineEnding(to: lineEnding)
                } label: {
                    Label {
                        Text(lineEnding.localizedName)
                    } icon: {
                        if document.metadata.selectedLineEnding == lineEnding {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(lineEndingLabel)
                .monospaced()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L10n.string("Line Endings"))
        .accessibilityLabel(L10n.format("Line endings: %@", lineEndingLabel))
        .accessibilityIdentifier("editor.status.line-endings")
        .disabled(!document.canModifyDocumentSettings)
    }

    private var indentMenu: some View {
        Menu {
            Button(L10n.string("Spaces")) { settings.indentStyle = .spaces }
            Button(L10n.string("Tabs")) { settings.indentStyle = .tabs }
        } label: {
            Text(settings.indentStyle == .spaces
                ? L10n.string("Spaces")
                : L10n.string("Tabs"))
                .monospaced()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L10n.string("Indent Using"))
        .accessibilityLabel(L10n.string("Indent Using"))
        .accessibilityIdentifier("editor.status.indent")
    }

    private var tabWidthMenu: some View {
        Menu {
            ForEach([1, 2, 4, 8, 16], id: \.self) { width in
                Button {
                    settings.setTabWidth(width)
                } label: {
                    Label {
                        Text("\(width)")
                    } icon: {
                        if settings.tabWidth == width {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text("\(settings.tabWidth)")
                .monospaced()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L10n.string("Tab Width"))
        .accessibilityLabel(L10n.format("Tab width: %d", settings.tabWidth))
        .accessibilityIdentifier("editor.status.tab-width")
    }

    private func detectedEncoding(for encoding: TextEncoding) -> DetectedEncoding {
        let byteOrder: ByteOrder
        switch encoding {
        case .utf8:
            byteOrder = .none
        case .utf16LittleEndian:
            byteOrder = .littleEndian
        case .utf16BigEndian:
            byteOrder = .bigEndian
        }

        return DetectedEncoding(
            encoding: encoding,
            byteOrder: byteOrder,
            bomPolicy: document.metadata.encoding.bomPolicy,
            confidence: .certain
        )
    }

    private var lineEndingLabel: String {
        if let selected = document.metadata.selectedLineEnding {
            return selected.localizedName
        }
        return L10n.string("Mixed")
    }

    private var statusAccessibilityLabel: String {
        L10n.format(
            "Line %d, column %d, %@, %@%@%@",
            session.textPosition.line,
            session.textPosition.column,
            document.metadata.encoding.encoding.localizedName,
            lineEndingLabel,
            L10n.format(
                ", %@, %d",
                settings.indentStyle == .spaces ? L10n.string("Spaces") : L10n.string("Tabs"),
                settings.tabWidth
            ),
            document.largeFileDisposition == .standard
                ? ""
                : L10n.string(", Large File Mode")
        )
    }

    private var fileSizeLabel: String {
        let byteCount = max(document.metadata.sourceByteCount, document.workingUTF8ByteCount)
        return ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}
