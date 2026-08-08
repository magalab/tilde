import AppKit
import XCTest
@testable import TildeEditor

@MainActor
final class EditorSessionTests: XCTestCase {
    func testPersistsSelectionScrollPositionAndModePerDocument() {
        let suiteName = "TildeEditorSessionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let url = URL(fileURLWithPath: "/tmp/example.md")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let session = EditorSession(documentURL: url, defaults: defaults)
        session.selection = NSRange(location: 12, length: 3)
        session.scrollPosition = CGPoint(x: 4, y: 96)
        session.mode = .split
        session.persist(defaults: defaults)

        let restored = EditorSession(documentURL: url, defaults: defaults)
        XCTAssertEqual(restored.selection, NSRange(location: 12, length: 3))
        XCTAssertEqual(restored.scrollPosition, CGPoint(x: 4, y: 96))
        XCTAssertEqual(restored.mode, .split)
    }

    func testUntitledSessionsDoNotPersist() {
        let suiteName = "TildeEditorSessionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let session = EditorSession(defaults: defaults)
        session.mode = .split
        session.persist(defaults: defaults)
        XCTAssertFalse(
            defaults.dictionaryRepresentation().keys.contains {
                $0.hasPrefix("document-session:")
            }
        )
    }
}
