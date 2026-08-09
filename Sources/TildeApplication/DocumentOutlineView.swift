import SwiftUI
import TildeCore
import TildeEditor

struct DocumentOutlineView: View {
    let headings: [MarkdownHeading]
    let select: @MainActor (MarkdownHeading) -> Void

    var body: some View {
        List(headings) { heading in
            Button {
                select(heading)
            } label: {
                HStack(spacing: 8) {
                    Text(heading.title)
                        .lineLimit(1)
                        .padding(.leading, CGFloat(max(0, heading.level - 1) * 14))
                    Spacer()
                    Text("\(heading.line)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 280, minHeight: 360)
        .navigationTitle(L10n.string("Document Outline"))
    }
}
