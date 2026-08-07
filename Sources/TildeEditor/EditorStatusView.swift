import SwiftUI
import TildeCore
import TildeDocument

public struct EditorStatusView: View {
    @ObservedObject private var document: TextDocument
    private let session: EditorSession

    public init(document: TextDocument, session: EditorSession) {
        self.document = document
        self.session = session
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(L10n.format("Ln %d, Col %d", session.textPosition.line, session.textPosition.column))
            Spacer()
            Text(document.metadata.encoding.encoding.localizedName)
            Text(lineEndingLabel)
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
    }

    private var lineEndingLabel: String {
        if let selected = document.metadata.selectedLineEnding {
            return selected.localizedName
        }
        return L10n.string("Mixed")
    }

    private var statusAccessibilityLabel: String {
        L10n.format(
            "Line %d, column %d, %@, %@%@",
            session.textPosition.line,
            session.textPosition.column,
            document.metadata.encoding.encoding.localizedName,
            lineEndingLabel,
            document.largeFileDisposition == .standard
                ? ""
                : L10n.string(", Large File Mode")
        )
    }
}
