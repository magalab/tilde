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

    func testNavigationHistoryMovesBackAndForward() {
        let session = EditorSession()
        let first = NSRange(location: 4, length: 0)
        let second = NSRange(location: 80, length: 0)
        session.recordNavigationLocation(first, beforeNavigatingTo: second)

        XCTAssertEqual(session.navigateBack(from: second, maximumLength: 100), first)
        XCTAssertEqual(session.navigateForward(from: first, maximumLength: 100), second)
    }

    func testNavigationHistoryClampsLocationsToCurrentDocument() {
        let session = EditorSession()
        let old = NSRange(location: 80, length: 20)
        session.recordNavigationLocation(old, beforeNavigatingTo: NSRange(location: 2, length: 0))
        XCTAssertEqual(
            session.navigateBack(from: NSRange(location: 2, length: 0), maximumLength: 10),
            NSRange(location: 10, length: 0)
        )
    }
}
