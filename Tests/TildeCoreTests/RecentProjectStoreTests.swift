import Foundation
import XCTest
@testable import TildeCore

@MainActor
final class RecentProjectStoreTests: XCTestCase {
    func testRecordsMostRecentDirectoriesWithBoundedUniqueList() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TildeRecent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first")
        let second = root.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: false)

        let store = RecentProjectStore(defaults: defaults, limit: 2)
        store.record(first)
        store.record(second)
        store.record(first)

        XCTAssertEqual(store.directories, [first.standardizedFileURL, second.standardizedFileURL])
        store.remove(first)
        XCTAssertEqual(store.directories, [second.standardizedFileURL])
    }

    func testDirectoriesDropsMissingPaths() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["/path/that/does/not/exist"], forKey: "projects")
        let store = RecentProjectStore(defaults: defaults, key: "projects")
        XCTAssertTrue(store.directories.isEmpty)
        XCTAssertEqual(defaults.stringArray(forKey: "projects"), [])
    }
}
