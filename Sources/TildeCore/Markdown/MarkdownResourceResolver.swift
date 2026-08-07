import Foundation

public enum MarkdownResourceResolver {
    public static func localResourceURL(
        for resourceURL: URL,
        documentDirectory: URL?
    ) -> URL? {
        guard let base = documentDirectory?.standardizedFileURL.resolvingSymlinksInPath() else {
            return nil
        }

        let candidate: URL
        if resourceURL.scheme == nil {
            candidate = base.appendingPathComponent(resourceURL.relativePath)
        } else {
            guard resourceURL.isFileURL else { return nil }
            candidate = resourceURL
        }

        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
        let basePath = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard resolved.path.hasPrefix(basePath) else { return nil }
        return resolved
    }

    public static func localResourceURL(
        for source: String,
        documentDirectory: URL?
    ) -> URL? {
        guard let url = URL(string: source) else { return nil }
        return localResourceURL(for: url, documentDirectory: documentDirectory)
    }
}
