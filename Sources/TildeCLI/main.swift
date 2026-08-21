import AppKit
import Foundation
import TildeCore

private final class OpenResult: @unchecked Sendable {
    let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var didSucceed = false

    func finish(app: NSRunningApplication?, error: Error?) {
        lock.lock()
        didSucceed = app != nil && error == nil
        lock.unlock()
        semaphore.signal()
    }

    var succeeded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didSucceed
    }
}

private func openURLsInTilde(_ urls: [URL]) -> Bool {
    guard let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: "tech.lury.tilde"
    ) else {
        return false
    }

    let result = OpenResult()
    NSWorkspace.shared.open(
        urls,
        withApplicationAt: applicationURL,
        configuration: NSWorkspace.OpenConfiguration()
    ) { app, error in
        result.finish(app: app, error: error)
    }
    result.semaphore.wait()
    return result.succeeded
}

let requests = TildeCommandLine.parse(Array(CommandLine.arguments.dropFirst()))
guard !requests.isEmpty else {
    FileHandle.standardError.write(Data("Usage: tilde [--new-window] [--line N] file...\n".utf8))
    exit(64)
}

for request in requests {
    let fileURL = URL(fileURLWithPath: request.path)
    var isDirectory: ObjCBool = false
    // The CLI owns creation of a missing path; the sandboxed app only opens
    // the file URL after Launch Services grants it access.
    if !FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
       !FileManager.default.createFile(atPath: fileURL.path, contents: Data()) {
        FileHandle.standardError.write(Data("Unable to create file at \(request.path)\n".utf8))
        exit(1)
    }
    if isDirectory.boolValue {
        FileHandle.standardError.write(Data("Cannot open directory \(request.path)\n".utf8))
        exit(1)
    }

    var urls = [fileURL]
    if request.line != nil || request.newWindow {
        var components = URLComponents()
        components.scheme = "tilde"
        components.host = "open"
        var queryItems = [URLQueryItem(name: "path", value: fileURL.standardizedFileURL.path)]
        if let line = request.line {
            queryItems.append(URLQueryItem(name: "line", value: String(line)))
        }
        if request.newWindow {
            queryItems.append(URLQueryItem(name: "newWindow", value: "1"))
        }
        components.queryItems = queryItems
        guard let metadataURL = components.url else {
            FileHandle.standardError.write(Data("Unable to encode request for \(request.path)\n".utf8))
            exit(1)
        }
        urls.append(metadataURL)
    }

    // Send the file URL and its metadata in one Launch Services request. This
    // keeps the metadata attached to the corresponding file open.
    guard openURLsInTilde(urls) else {
        FileHandle.standardError.write(Data("Unable to open file \(request.path)\n".utf8))
        exit(1)
    }
}
