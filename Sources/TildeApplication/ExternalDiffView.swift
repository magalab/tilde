import SwiftUI
import TildeCore

struct ExternalDiffView: View {
    let localText: String
    let externalText: String
    let mergedText: String
    let hasConflicts: Bool
    let useDisk: @MainActor () -> Void
    let applyMerge: @MainActor () -> Void
    let keepLocal: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                textColumn(
                    title: L10n.string("Local Changes"),
                    text: localText,
                    identifier: "external-diff.local"
                )
                textColumn(
                    title: L10n.string("On Disk"),
                    text: externalText,
                    identifier: "external-diff.disk"
                )
                textColumn(
                    title: L10n.string("Merged Result"),
                    text: mergedText,
                    identifier: "external-diff.merged"
                )
            }
            Divider()
            HStack {
                if hasConflicts {
                    Label(L10n.string("Merge contains conflicts"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Label(L10n.string("Merge is conflict-free"), systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                Spacer()
                Button(L10n.string("Keep Local"), action: keepLocal)
                    .accessibilityIdentifier("external-diff.keep-local")
                Button(L10n.string("Use Disk Version"), action: useDisk)
                    .accessibilityIdentifier("external-diff.use-disk")
                Button(L10n.string("Apply Merge"), action: applyMerge)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("external-diff.apply-merge")
            }
            .padding(10)
        }
        .frame(minWidth: 980, minHeight: 560)
    }

    private func textColumn(title: String, text: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(10)
            Divider()
            ScrollView([.vertical, .horizontal]) {
                Text(text.isEmpty ? " " : text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(title)
        }
    }
}
