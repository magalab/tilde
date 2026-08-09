import AppKit
import Foundation
import TildeCore

let requests = TildeCommandLine.parse(Array(CommandLine.arguments.dropFirst()))
guard !requests.isEmpty else {
    FileHandle.standardError.write(Data("Usage: tilde [--new-window] [--line N] file...\n".utf8))
    exit(64)
}

for request in requests {
    var components = URLComponents()
    components.scheme = "tilde"
    components.host = "open"
    var queryItems = [URLQueryItem(name: "path", value: request.path)]
    if let line = request.line {
        queryItems.append(URLQueryItem(name: "line", value: String(line)))
    }
    if request.newWindow {
        queryItems.append(URLQueryItem(name: "newWindow", value: "1"))
    }
    components.queryItems = queryItems
    guard let url = components.url, NSWorkspace.shared.open(url) else {
        FileHandle.standardError.write(Data("Unable to send request for \(request.path)\n".utf8))
        exit(1)
    }
}
