import Foundation

@MainActor
public final class DocumentRestoreStore {
    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    public init(
        defaults: UserDefaults = .standard,
        key: String = "document-restore-session",
        limit: Int = 24
    ) {
        self.defaults = defaults
        self.key = key
        self.limit = max(1, limit)
    }

    public var urls: [URL] {
        let paths = defaults.stringArray(forKey: key) ?? []
        let valid = paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.isReadableFile(atPath: url.path) else { return nil }
            return url
        }
        let unique = valid.reduce(into: [URL]()) { result, url in
            if !result.contains(url) { result.append(url) }
        }
        let result = Array(unique.prefix(limit))
        if result.map(\.path) != paths {
            defaults.set(result.map(\.path), forKey: key)
        }
        return result
    }

    public func replace(with urls: [URL]) {
        var unique: [URL] = []
        for url in urls {
            let normalized = url.standardizedFileURL
            guard !unique.contains(normalized) else { continue }
            unique.append(normalized)
            if unique.count == limit { break }
        }
        defaults.set(unique.map(\.path), forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
