import SwiftUI
import TildeCore

struct CommandPaletteItem: Identifiable {
    let id: String
    let title: String
    let shortcut: String
    let action: @MainActor () -> Void
}

struct CommandPaletteView: View {
    let items: [CommandPaletteItem]
    let dismiss: @MainActor () -> Void
    @State private var query = ""
    @State private var selectedID: String?

    private var filteredItems: [CommandPaletteItem] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(L10n.string("Search Commands"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .accessibilityIdentifier("command-palette.search")
                .onSubmit(performSelected)
                .onMoveCommand { direction in moveSelection(direction) }

            Divider()

            List(filteredItems, selection: $selectedID) { item in
                Button {
                    run(item)
                } label: {
                    HStack {
                        Text(item.title)
                        Spacer()
                        if !item.shortcut.isEmpty {
                            Text(item.shortcut)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tag(item.id)
            }
            .listStyle(.plain)
            .accessibilityIdentifier("command-palette.results")
            .onMoveCommand { direction in moveSelection(direction) }
        }
        .frame(width: 460, height: 360)
        .onAppear {
            selectedID = filteredItems.first?.id
        }
        .onChange(of: query) { _, _ in
            selectedID = filteredItems.first?.id
        }
        .onChange(of: filteredItems.map(\.id)) { _, ids in
            if let selectedID, ids.contains(selectedID) == false {
                self.selectedID = ids.first
            }
        }
    }

    private func performSelected() {
        guard let selectedID,
              let item = filteredItems.first(where: { $0.id == selectedID })
        else { return }
        run(item)
    }

    private func run(_ item: CommandPaletteItem) {
        item.action()
        dismiss()
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !filteredItems.isEmpty else { return }
        let currentIndex = selectedID.flatMap { id in
            filteredItems.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = currentIndex == 0 ? filteredItems.count - 1 : currentIndex - 1
        case .down:
            nextIndex = (currentIndex + 1) % filteredItems.count
        default:
            return
        }
        selectedID = filteredItems[nextIndex].id
    }
}
