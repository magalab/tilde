import SwiftUI
import TildeCore

struct QuickOpenCandidate: Identifiable {
    let id: URL
    let title: String
    let detail: String
}

struct QuickOpenView: View {
    let candidates: [QuickOpenCandidate]
    let recentDirectories: [URL]
    let open: @MainActor (URL) -> Void
    let openDirectory: @MainActor (URL) -> Void
    let chooseDirectory: @MainActor () -> Void
    let dismiss: @MainActor () -> Void
    @State private var query = ""
    @State private var selectedID: URL?

    private var filtered: [QuickOpenCandidate] {
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField(L10n.string("Search Files"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("quick-open.search")
                    .onSubmit(performSelected)
                    .onMoveCommand { direction in moveSelection(direction) }
                Button {
                    chooseDirectory()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(L10n.string("Choose Folder"))
                .accessibilityLabel(L10n.string("Choose Folder"))
                .accessibilityIdentifier("quick-open.choose-folder")
            }
            .padding(12)

            Divider()

            List(selection: $selectedID) {
                if !recentDirectories.isEmpty && query.isEmpty {
                    Section(L10n.string("Recent Projects")) {
                        ForEach(recentDirectories, id: \.self) { directory in
                            Button {
                                openDirectory(directory)
                                dismiss()
                            } label: {
                                Label(directory.lastPathComponent, systemImage: "folder")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .tag(directory)
                        }
                    }
                }

                Section(L10n.string("Files")) {
                    ForEach(filtered) { candidate in
                        Button {
                            open(candidate.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title).lineLimit(1)
                                Text(candidate.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .tag(candidate.id)
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("quick-open.results")
            .onMoveCommand { direction in moveSelection(direction) }
        }
        .frame(width: 600, height: 420)
        .onAppear { selectedID = filtered.first?.id }
        .onChange(of: query) { _, _ in selectedID = filtered.first?.id }
    }

    private func performSelected() {
        guard let selectedID,
              let candidate = filtered.first(where: { $0.id == selectedID })
        else { return }
        open(candidate.id)
        dismiss()
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !filtered.isEmpty else { return }
        let currentIndex = selectedID.flatMap { id in
            filtered.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = currentIndex == 0 ? filtered.count - 1 : currentIndex - 1
        case .down:
            nextIndex = (currentIndex + 1) % filtered.count
        default:
            return
        }
        selectedID = filtered[nextIndex].id
    }
}
