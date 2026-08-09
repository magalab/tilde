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
        XCTAssertEqual(store.urls, [urls[0].standardizedFileURL, urls[1].standardizedFileURL])
    }

    func testRestoreStoreRemovesFilesThatNoLongerExist() throws {
        let suiteName = "TildeCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["/path/that/does/not/exist"], forKey: "restore")
        let store = DocumentRestoreStore(defaults: defaults, key: "restore")
        XCTAssertTrue(store.urls.isEmpty)
    }
}
