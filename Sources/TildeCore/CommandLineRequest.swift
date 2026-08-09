import Foundation

public struct TildeOpenRequest: Equatable, Sendable {
    public let path: String
    public let line: Int?
    public let newWindow: Bool

    public init(path: String, line: Int? = nil, newWindow: Bool = false) {
        self.path = path
        self.line = line
        self.newWindow = newWindow
    }
}

public enum TildeCommandLine {
    public static func parse(
        _ arguments: [String],
        currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> [TildeOpenRequest] {
        var requests: [TildeOpenRequest] = []
        var line: Int?
        var newWindow = false
        var acceptsOptions = true
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if acceptsOptions, argument == "--" {
                acceptsOptions = false
                index += 1
                continue
            }
            if acceptsOptions, argument == "--new-window" {
                newWindow = true
                index += 1
                continue
            }
            if acceptsOptions, argument == "--line", index + 1 < arguments.count {
                line = positiveLine(arguments[index + 1])
                index += 2
                continue
            }
            if acceptsOptions, argument.hasPrefix("--line=") {
                line = positiveLine(String(argument.dropFirst("--line=".count)))
                index += 1
                continue
            }
            if argument.hasPrefix("-psn_") {
                index += 1
                continue
            }

            let pathAndLine = splitPathAndLine(argument)
            let url: URL
            if pathAndLine.path.hasPrefix("/") {
                url = URL(fileURLWithPath: pathAndLine.path).standardizedFileURL
            } else {
                url = currentDirectory
                    .appendingPathComponent(pathAndLine.path)
                    .standardizedFileURL
            }
            requests.append(TildeOpenRequest(
                path: url.path,
                line: line ?? pathAndLine.line,
                newWindow: newWindow
            ))
            line = nil
            index += 1
        }

        return requests
    }

    private static func positiveLine(_ value: String) -> Int? {
        guard let line = Int(value), line > 0 else { return nil }
        return line
    }

    private static func splitPathAndLine(_ argument: String) -> (path: String, line: Int?) {
        guard let separator = argument.lastIndex(of: ":") else {
            return (argument, nil)
        }
        let suffixStart = argument.index(after: separator)
        let suffix = String(argument[suffixStart...])
        guard let line = positiveLine(suffix) else {
            return (argument, nil)
        }
        let path = String(argument[..<separator])
        return path.isEmpty ? (argument, nil) : (path, line)
    }
}
