import Foundation

@MainActor
public final class DocumentRestoreStore {
    private let defaults: UserDefaults
    private let key: String
    private let bookmarkKey: String
    private let legacyBookmarkKey: String
    private let legacyRetryCountKey: String
    private let limit: Int
    /// Paths `loadURLs()` could not resolve during this launch. `replace(with:)`
    /// carries their bookmarks forward, so an unmounted volume does not cost the
    /// user the entry. Paths absent from this list — the ones the user actually
    /// closed — still drop out of the session.
    private var unresolvedPathsFromLastLoad: [String] = []

    public init(
        defaults: UserDefaults = .standard,
        key: String = "document-restore-session",
        limit: Int = 24
    ) {
        self.defaults = defaults
        self.key = key
        bookmarkKey = "\(key)-bookmarks"
        legacyBookmarkKey = "\(key)-legacy-bookmarks"
        legacyRetryCountKey = "\(key)-legacy-bookmark-retries"
        self.limit = max(1, limit)
        migrateLegacyBookmarkArrayIfNeeded()
    }

    public func loadURLs() -> [URL] {
        let paths = defaults.stringArray(forKey: key) ?? []
        let resolution = resolvedBookmarkURLs(in: paths)
        let bookmarkURLs = resolution.urls
        let readablePathKeys = Set(paths.compactMap { path -> String? in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                return nil
            }
            return pathKey(for: url)
        })

        // A readable plain path is already usable. Prefer the security-scoped
        // bookmark for paths that need it, while retaining the stored order.
        var candidates = bookmarkURLs.filter {
            !readablePathKeys.contains(pathKey(for: $0))
        }
        candidates.append(contentsOf: paths.map {
            URL(fileURLWithPath: $0).standardizedFileURL
        })

        var valid: [URL] = []
        for (index, url) in candidates.enumerated() {
            let isBookmark = index < candidates.count - paths.count
            guard (isBookmark || FileManager.default.isReadableFile(atPath: url.path)),
                  !valid.contains(where: {
                      pathKey(for: $0) == pathKey(for: url)
                  })
            else { continue }
            valid.append(url)
        }

        let result = Array(valid.prefix(limit))
        var resultPaths = result.map(\.path)
        let unresolvedPaths = resolution.unresolvedPaths
        let unresolvedPathKeys = Set(unresolvedPaths.map {
            pathKey(for: URL(fileURLWithPath: $0))
        })
        for path in paths where unresolvedPathKeys.contains(pathKey(for: URL(fileURLWithPath: path))) {
            if !resultPaths.contains(path) {
                resultPaths.append(path)
            }
        }
        for path in unresolvedPaths where !resultPaths.contains(path) {
            resultPaths.append(path)
        }
        if resultPaths.count > limit {
            resultPaths = Array(resultPaths.prefix(limit))
        }
        if resultPaths != paths {
            defaults.set(resultPaths, forKey: key)
        }
        // Keep the original path keys while retrying unresolved bookmarks.
        // Once a path is explicitly removed from the session, it will no
        // longer be included here and its mapped bookmark can be pruned.
        pruneBookmarks(
            to: Set(paths + resultPaths),
            preserving: unresolvedPaths
        )
        unresolvedPathsFromLastLoad = unresolvedPaths
        return result
    }

    public func replace(with urls: [URL]) {
        var unique: [URL] = []
        for url in urls {
            let normalized = url.standardizedFileURL
            guard !unique.contains(where: {
                $0.standardizedFileURL == normalized
            }) else { continue }
            // Keep the original URL so a security-scoped URL remains attached
            // while bookmarkData is being created. Normalize only storage and
            // deduplication keys.
            unique.append(url)
            if unique.count == limit { break }
        }
        defaults.set(unique.map { $0.standardizedFileURL.path }, forKey: key)

        // Read raw values only. Resolving bookmark data here would make a
        // transiently unavailable volume destroy an otherwise recoverable
        // bookmark.
        let previousBookmarks = bookmarkDataByPath()
        var bookmarks: [String: Data] = [:]
        for url in unique {
            let path = url.standardizedFileURL.path
            if let data = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                bookmarks[path] = data
            } else if let data = previousBookmarks[path] {
                bookmarks[path] = data
            }
        }

        carryForwardUnresolvedEntries(
            into: &bookmarks,
            from: previousBookmarks,
            openPaths: unique.map { $0.standardizedFileURL.path }
        )

        if bookmarks.isEmpty {
            defaults.removeObject(forKey: bookmarkKey)
        } else {
            defaults.set(bookmarks, forKey: bookmarkKey)
        }
        // Unresolved legacy entries intentionally remain in legacyBookmarkKey.
    }

    /// Merges additional URLs into the persisted session without dropping the
    /// ones already saved.
    ///
    /// Use this when the user opens files in response to an OS event (Finder
    /// double-click, URL handler) before the app has had a chance to call
    /// `loadURLs()`. Unlike `replace(with:)`, this entry point treats the
    /// stored session as authoritative and only appends; the next normal quit
    /// is what reconciles the working set.
    public func merge(with urls: [URL]) {
        let existingPaths = defaults.stringArray(forKey: key) ?? []
        let existingBookmarks = bookmarkDataByPath()
        var storedPaths = existingPaths
        var bookmarks = existingBookmarks

        for url in urls {
            let path = url.standardizedFileURL.path
            guard storedPaths.count < limit else { break }
            guard !storedPaths.contains(path) else { continue }
            if let data = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                bookmarks[path] = data
            }
            storedPaths.append(path)
            if storedPaths.count >= limit { break }
        }

        if storedPaths != existingPaths {
            defaults.set(storedPaths, forKey: key)
        }
        if bookmarks.isEmpty {
            defaults.removeObject(forKey: bookmarkKey)
        } else if bookmarks != existingBookmarks {
            defaults.set(bookmarks, forKey: bookmarkKey)
        }
        // Unresolved legacy entries intentionally remain in legacyBookmarkKey.
    }

    /// Restores the entries `loadURLs()` could not open this launch.
    ///
    /// Without this, a session opened while an external volume was unmounted
    /// would overwrite the stored session with only the documents that happened
    /// to be reachable, and quitting once would discard the rest permanently.
    private func carryForwardUnresolvedEntries(
        into bookmarks: inout [String: Data],
        from previousBookmarks: [String: Data],
        openPaths: [String]
    ) {
        guard !unresolvedPathsFromLastLoad.isEmpty else { return }

        var storedPaths = openPaths
        for path in unresolvedPathsFromLastLoad where bookmarks[path] == nil {
            guard let data = previousBookmarks[path],
                  storedPaths.count < limit
            else { continue }
            bookmarks[path] = data
            storedPaths.append(path)
        }
        if storedPaths != openPaths {
            defaults.set(storedPaths, forKey: key)
        }
    }

    public func clear() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: bookmarkKey)
        defaults.removeObject(forKey: legacyBookmarkKey)
        defaults.removeObject(forKey: legacyRetryCountKey)
        unresolvedPathsFromLastLoad = []
    }

    private func resolvedBookmarkURLs(in paths: [String]) -> (
        urls: [URL],
        unresolvedPaths: [String]
    ) {
        var bookmarks = bookmarkDataByPath()
        var changed = false
        var resolved: [URL] = []
        var unresolvedPaths: [String] = []

        // The restore path list is the source of ordering. Dictionary iteration
        // order is deliberately never used for session restoration.
        let orderedPaths = paths + bookmarks.keys
            .filter { !paths.contains($0) }
            .sorted()
        for path in orderedPaths {
            guard let data = bookmarks[path] else {
                // A plain path has no security-scoped bookmark to retry. Let
                // the normal readable-path filtering remove it if it is gone.
                continue
            }
            guard let entry = resolve(data) else {
                unresolvedPaths.append(path)
                continue
            }
            let url = entry.url
            var storedData = data
            if entry.isStale, let refreshed = refreshedBookmarkData(for: url) {
                storedData = refreshed
            }
            if storedData != data {
                bookmarks[path] = storedData
                changed = true
            }
            resolved.append(url)
        }

        if let legacyData = legacyBookmarkDataForRetry() {
            var unresolvedLegacy: [Data] = []
            for data in legacyData {
                guard let entry = resolve(data) else {
                    unresolvedLegacy.append(data)
                    continue
                }
                let url = entry.url
                let path = url.standardizedFileURL.path
                let storedData = entry.isStale
                    ? (refreshedBookmarkData(for: url) ?? data)
                    : data
                if bookmarks[path] != storedData {
                    bookmarks[path] = storedData
                    changed = true
                }
                resolved.append(url)
            }
            if unresolvedLegacy.isEmpty {
                defaults.removeObject(forKey: legacyBookmarkKey)
                defaults.removeObject(forKey: legacyRetryCountKey)
            } else {
                defaults.set(unresolvedLegacy, forKey: legacyBookmarkKey)
            }
        }

        if changed {
            defaults.set(bookmarks, forKey: bookmarkKey)
        }
        return (resolved, unresolvedPaths)
    }

    private func bookmarkDataByPath() -> [String: Data] {
        defaults.dictionary(forKey: bookmarkKey) as? [String: Data] ?? [:]
    }

    private func legacyBookmarkData() -> [Data] {
        defaults.array(forKey: legacyBookmarkKey) as? [Data] ?? []
    }

    private func migrateLegacyBookmarkArrayIfNeeded() {
        guard let values = defaults.array(forKey: bookmarkKey) as? [Data] else {
            return
        }

        var bookmarks: [String: Data] = [:]
        var unresolved = defaults.array(forKey: legacyBookmarkKey) as? [Data] ?? []
        for data in values {
            guard let entry = resolve(data) else {
                unresolved.append(data)
                continue
            }
            let url = entry.url
            bookmarks[url.standardizedFileURL.path] = data
        }
        if bookmarks.isEmpty {
            defaults.removeObject(forKey: bookmarkKey)
        } else {
            defaults.set(bookmarks, forKey: bookmarkKey)
        }
        if unresolved.isEmpty {
            defaults.removeObject(forKey: legacyBookmarkKey)
        } else {
            defaults.set(unresolved, forKey: legacyBookmarkKey)
        }
    }

    private func legacyBookmarkDataForRetry() -> [Data]? {
        guard let values = defaults.array(forKey: legacyBookmarkKey) as? [Data],
              !values.isEmpty else {
            defaults.removeObject(forKey: legacyRetryCountKey)
            return nil
        }
        // A legacy bookmark may refer to an external volume that is absent for
        // an arbitrary number of launches. Keep trying until it resolves; the
        // data is small and a failed resolution is already handled cheaply.
        defaults.removeObject(forKey: legacyRetryCountKey)
        return values
    }

    private func pruneBookmarks(to paths: Set<String>, preserving unresolvedPaths: [String]) {
        let bookmarks = bookmarkDataByPath()
        let canonicalPaths = Set(paths.union(unresolvedPaths).map {
            pathKey(for: URL(fileURLWithPath: $0))
        })
        let pruned = bookmarks.filter {
            canonicalPaths.contains(pathKey(for: URL(fileURLWithPath: $0.key)))
        }
        if pruned.isEmpty {
            defaults.removeObject(forKey: bookmarkKey)
        } else if pruned != bookmarks {
            defaults.set(pruned, forKey: bookmarkKey)
        }
        // Raw legacy data has no reliable path key. Keep it rather than
        // deleting it merely because its volume is currently unavailable.
    }

    private func resolve(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return (url, isStale)
    }

    private func refreshedBookmarkData(for url: URL) -> Data? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func pathKey(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
