import Foundation

@MainActor
public final class RecentProjectStore {
    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    public init(
        defaults: UserDefaults = .standard,
        key: String = "recent-project-directories",
        limit: Int = 12
    ) {
        self.defaults = defaults
        self.key = key
        self.limit = max(1, limit)
    }

    public var directories: [URL] {
        let paths = defaults.stringArray(forKey: key) ?? []
        let valid = paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return nil }
            return url
        }
        let unique = Array(NSOrderedSet(array: valid)) as? [URL] ?? valid
        let result = Array(unique.prefix(limit))
        if result.map(\.path) != paths {
            defaults.set(result.map(\.path), forKey: key)
        }
        return result
    }

    public func record(_ directory: URL) {
        let normalized = directory.standardizedFileURL
        var values = directories.filter { $0 != normalized }
        values.insert(normalized, at: 0)
        defaults.set(Array(values.prefix(limit)).map(\.path), forKey: key)
    }

    public func remove(_ directory: URL) {
        let normalized = directory.standardizedFileURL
        defaults.set(directories.filter { $0 != normalized }.map(\.path), forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
