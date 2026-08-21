import Foundation
import XCTest
@testable import TildeCore

@MainActor
final class DocumentRestoreStoreTests: XCTestCase {
    func testRestoreStoreDeduplicatesAndBoundsDocuments() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TildeRestore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let urls = (0..<3).map { index in
            let url = root.appendingPathComponent("file-\(index).txt")
            FileManager.default.createFile(atPath: url.path, contents: Data())
            return url
        }

        let store = DocumentRestoreStore(defaults: defaults, limit: 2)
        store.replace(with: [urls[0], urls[1], urls[0], urls[2]])
        XCTAssertEqual(store.loadURLs(), [urls[0].standardizedFileURL, urls[1].standardizedFileURL])
    }

    func testRestoreStoreRemovesFilesThatNoLongerExist() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["/path/that/does/not/exist"], forKey: "restore")
        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        XCTAssertTrue(store.loadURLs().isEmpty)
        XCTAssertEqual(defaults.stringArray(forKey: "restore"), [])
    }

    func testRestoreStoreRetainsUnresolvableBookmarkAcrossLoads() {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let path = "/Volumes/Offline/bookmarked.txt"
        let data = Data([0x01, 0x02, 0x03])
        defaults.set([path], forKey: "restore")
        defaults.set([path: data], forKey: "restore-bookmarks")

        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        XCTAssertTrue(store.loadURLs().isEmpty)
        XCTAssertTrue(store.loadURLs().isEmpty)
        XCTAssertEqual(
            (defaults.dictionary(forKey: "restore-bookmarks") as? [String: Data])?[path],
            data
        )
        XCTAssertEqual(defaults.stringArray(forKey: "restore"), [path])
    }

    func testRestoreStoreCarriesUnresolvableBookmarksThroughReplace() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let offlinePath = "/Volumes/Offline/bookmarked.txt"
        let offlineData = Data([0x10, 0x20, 0x30])
        defaults.set([offlinePath], forKey: "restore")
        defaults.set([offlinePath: offlineData], forKey: "restore-bookmarks")

        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        XCTAssertTrue(store.loadURLs().isEmpty)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TildeRestore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let openURL = root.appendingPathComponent("open.txt")
        FileManager.default.createFile(atPath: openURL.path, contents: Data())

        store.replace(with: [openURL])

        let storedBookmarks = defaults.dictionary(forKey: "restore-bookmarks") as? [String: Data] ?? [:]
        XCTAssertEqual(storedBookmarks[offlinePath], offlineData,
            "An unresolvable entry should survive a replace() that only sees open documents.")
        XCTAssertEqual(defaults.stringArray(forKey: "restore"), [
            openURL.standardizedFileURL.path,
            offlinePath,
        ])
    }

    func testReplaceDropsPathsThatLoadURLsCouldResolve() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TildeRestore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kept = root.appendingPathComponent("kept.txt")
        let closed = root.appendingPathComponent("closed.txt")
        FileManager.default.createFile(atPath: kept.path, contents: Data())
        FileManager.default.createFile(atPath: closed.path, contents: Data())

        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        let firstLoad = store.loadURLs().isEmpty
        XCTAssertTrue(firstLoad)

        store.replace(with: [kept])

        let storedPaths = defaults.stringArray(forKey: "restore") ?? []
        XCTAssertEqual(storedPaths, [kept.standardizedFileURL.path],
            "Paths the user actively closes should drop out of the session, even after loadURLs resolved them.")
        let storedBookmarks = defaults.dictionary(forKey: "restore-bookmarks") as? [String: Data] ?? [:]
        XCTAssertNil(storedBookmarks[closed.standardizedFileURL.path])
    }

    func testMergeAppendsWithoutDroppingStoredSession() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let savedPaths = ["/saved/A.txt", "/saved/B.txt", "/saved/C.txt"]
        defaults.set(savedPaths, forKey: "restore")

        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        store.merge(with: [URL(fileURLWithPath: "/saved/D.txt")])

        XCTAssertEqual(defaults.stringArray(forKey: "restore"), savedPaths + ["/saved/D.txt"],
            "merge(with:) must not overwrite the saved session with a partial view.")
    }

    func testMergeIsIdempotentForPathsAlreadyStored() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let path = "/saved/A.txt"
        defaults.set([path], forKey: "restore")

        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        store.merge(with: [URL(fileURLWithPath: path)])

        XCTAssertEqual(defaults.stringArray(forKey: "restore"), [path])
    }

    func testMergeDoesNotExceedLimit() {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let savedPaths = ["/saved/A.txt", "/saved/B.txt"]
        defaults.set(savedPaths, forKey: "restore")

        let store = DocumentRestoreStore(defaults: defaults, key: "restore", limit: 2)
        store.merge(with: [URL(fileURLWithPath: "/saved/C.txt")])

        XCTAssertEqual(defaults.stringArray(forKey: "restore"), savedPaths)
    }
}
