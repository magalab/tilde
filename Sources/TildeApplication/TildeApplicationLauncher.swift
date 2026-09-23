import AppKit
import OSLog
import SwiftUI
import TildeCore
import TildeDocument
import TildeEditor

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let documentController = TextDocumentController()
    let settings = EditorSettings()
    let recentProjects = RecentProjectStore()
    let restoreStore = DocumentRestoreStore()
    var settingsWindowController: NSWindowController?
    var commandPaletteWindowController: NSWindowController?
    var outlineWindowController: NSWindowController?
    var quickOpenWindowController: NSWindowController?
    // Prevents delayed session restoration from creating a fallback document after
    // Finder or Launch Services has already delivered an open-file request. The
    // application(_:open:) entry point must set this synchronously before
    // dispatching any custom URL-opening work.
    private var receivedOpenURLs = false
    private var hasStartupUntitledDocument = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "tech.lury.tilde",
        category: "CommandLine"
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        documentController.newDocumentMetadataProvider = { [settings] in
            DocumentMetadata(
                encoding: settings.defaultEncoding.detectedEncoding,
                lineEndings: LineEndingProfile(),
                selectedLineEnding: settings.defaultLineEnding,
                documentType: TildeDocumentType.plainText
            )
        }
        TextDocument.windowControllerFactory = { [settings] document in
            DocumentWindowController(document: document, settings: settings)
        }
        NSApp.mainMenu = MainMenuBuilder.make(
            documentController: documentController,
            actionTarget: self
        )
        NSApp.windowsMenu = NSApp.mainMenu?.item(withTitle: L10n.string("Window"))?.submenu
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let launchValue = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? NSNumber
        let isDefaultLaunch = launchValue?.boolValue ?? true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let requests = TildeCommandLine.parse(Array(CommandLine.arguments.dropFirst()))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard !self.receivedOpenURLs else { return }
                if requests.isEmpty, isDefaultLaunch {
                    self.restoreLastSessionIfNeeded()
                } else if !requests.isEmpty {
                    self.openCommandLineRequestsAtStartup(requests)
                } else {
                    self.removeCleanUntitledDocumentsIfFileIsOpen()
                }
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist bookmarks before releasing document-owned security scopes.
        restoreStore.replace(
            with: documentController.documents.compactMap { ($0 as? TextDocument)?.fileURL }
        )
        documentController.releaseRetainedSecurityScopedAccess()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedOpenURLs = true
        discardStartupUntitledDocumentIfNeeded()
        handleOpenRequests(urls)
    }

    private func handleOpenRequests(_ urls: [URL]) {
        let commandLineRequests = urls.compactMap(Self.request(from:))
        let fileURLs = urls.filter(\.isFileURL)
        let requestsByFile = Dictionary(
            grouping: commandLineRequests,
            by: { fileKey(for: URL(fileURLWithPath: $0.path)) }
        )
        let fileKeys = Set(fileURLs.map(fileKey(for:)))
        open(commandLineRequests: commandLineRequests.filter {
            !fileKeys.contains(fileKey(for: URL(fileURLWithPath: $0.path)))
        })

        for url in fileURLs {
            let requests = requestsByFile[fileKey(for: url)] ?? []
            documentController.openDocument(
                withContentsOf: url,
                display: !requests.contains(where: { $0.newWindow }),
                completionHandler: { [weak self] document, wasAlreadyOpen, error in
                    if let error {
                        NSApp.presentError(error)
                        return
                    }
                    guard let self, let document = document as? TextDocument else {
                        return
                    }
                    self.discardStartupUntitledDocumentIfNeeded()
                    self.restoreStore.merge(with: [url])
                    let key = self.fileKey(for: url)
                    for request in requestsByFile[key] ?? [] {
                        self.applyCommandLineRequest(
                            request,
                            to: document,
                            wasAlreadyOpen: wasAlreadyOpen
                        )
                    }
                }
            )
            recentProjects.record(url.deletingLastPathComponent())
        }
    }

    @objc func newDocumentInNewWindow(_ sender: Any?) {
        documentController.newDocumentInSeparateWindow()
    }

    @objc func showCommandPalette(_ sender: Any?) {
        let view = CommandPaletteView(
            items: commandPaletteItems(),
            dismiss: { [weak self] in
                self?.commandPaletteWindowController?.close()
            }
        )
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.string("Command Palette")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        commandPaletteWindowController = NSWindowController(window: window)
        commandPaletteWindowController?.showWindow(sender)
        window.center()
        window.makeKeyAndOrderFront(sender)
    }

    func showQuickOpenWindow(at directory: URL? = nil) {
        let baseDirectory = directory
            ?? currentDocument?.fileURL?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser
        let candidates = quickOpenCandidates(in: baseDirectory)
        let view = QuickOpenView(
            candidates: candidates,
            recentDirectories: recentProjects.directories,
            open: { [weak self] url in self?.openQuickOpenURL(url) },
            openDirectory: { [weak self] url in
                self?.recentProjects.record(url)
                self?.showQuickOpenWindow(at: url)
            },
            chooseDirectory: { [weak self] in self?.chooseQuickOpenDirectory() },
            dismiss: { [weak self] in self?.quickOpenWindowController?.close() }
        )
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.string("Quick Open")
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        quickOpenWindowController = NSWindowController(window: window)
        quickOpenWindowController?.showWindow(nil)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func chooseQuickOpenDirectory() {
        let panel = NSOpenPanel()
        panel.title = L10n.string("Choose Folder")
        panel.prompt = L10n.string("Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let directory = panel.url else { return }
            self?.recentProjects.record(directory)
            self?.showQuickOpenWindow(at: directory)
        }
    }

    private func openQuickOpenURL(_ url: URL) {
        recentProjects.record(url.deletingLastPathComponent())
        documentController.openDocument(
            withContentsOf: url,
            display: true,
            completionHandler: { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        )
    }

    private func restoreLastSessionIfNeeded() {
        // Launch Services may have already opened a file through NSDocumentController
        // before the delayed startup fallback runs. In that case creating the normal
        // fallback document would leave an extra Untitled tab behind.
        if documentController.documents.contains(where: { document in
            (document as? TextDocument)?.fileURL != nil
        }) {
            hasStartupUntitledDocument = hasCleanUntitledDocument
            discardStartupUntitledDocumentIfNeeded()
            return
        }

        let urls = restoreStore.loadURLs()
        if urls.isEmpty {
            if !hasCleanUntitledDocument {
                _ = documentController.makeAndShowUntitledDocument()
            }
            hasStartupUntitledDocument = true
            return
        }

        // Remove stale clean Untitled windows restored by AppKit before restoring
        // the persisted file session.
        hasStartupUntitledDocument = hasCleanUntitledDocument
        discardStartupUntitledDocumentIfNeeded()

        for url in urls {
            documentController.openDocument(
                withContentsOf: url,
                display: true,
                completionHandler: { [weak self] document, _, error in
                    if let error {
                        NSApp.presentError(error)
                        return
                    }
                    if let fileURL = (document as? TextDocument)?.fileURL {
                        self?.recentProjects.record(fileURL.deletingLastPathComponent())
                    }
                }
            )
        }
    }

    /// The launch-time blank document is only a fallback for a plain app launch. Finder can
    /// deliver an open-file event just after launch, so remove that fallback before displaying
    /// the requested file instead of leaving an extra focused tab behind.
    private func discardStartupUntitledDocumentIfNeeded() {
        guard hasStartupUntitledDocument else { return }
        hasStartupUntitledDocument = false

        removeCleanUntitledDocuments()
    }

    private var hasCleanUntitledDocument: Bool {
        documentController.documents.contains { document in
            (document as? TextDocument)?.isUntitledAndUnmodified == true
        }
    }

    private func removeCleanUntitledDocumentsIfFileIsOpen(retriesRemaining: Int = 5) {
        guard documentController.documents.contains(where: { document in
            (document as? TextDocument)?.fileURL != nil
        }) else {
            guard retriesRemaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.removeCleanUntitledDocumentsIfFileIsOpen(
                    retriesRemaining: retriesRemaining - 1
                )
            }
            return
        }
        removeCleanUntitledDocuments()
    }

    private func removeCleanUntitledDocuments() {
        let documents = documentController.documents
            .compactMap { $0 as? TextDocument }
            .filter(\.isUntitledAndUnmodified)
        for document in documents {
            document.windowControllers.forEach { $0.close() }
            documentController.removeDocument(document)
        }
    }

    private func quickOpenCandidates(in directory: URL) -> [QuickOpenCandidate] {
        var urls = Set<URL>()
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) {
            for case let url as URL in enumerator {
                guard urls.count < 1000,
                      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                else { continue }
                urls.insert(url.standardizedFileURL)
            }
        }
        for url in documentController.recentDocumentURLs {
            if FileManager.default.fileExists(atPath: url.path) {
                urls.insert(url.standardizedFileURL)
            }
        }
        return urls.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
            .map { url in
                QuickOpenCandidate(
                    id: url,
                    title: url.lastPathComponent,
                    detail: url.path
                )
            }
    }

    private func commandPaletteItems() -> [CommandPaletteItem] {
        var items = [
            CommandPaletteItem(
                id: "quick-open",
                title: L10n.string("Quick Open…"),
                shortcut: "⌘P",
                action: { [weak self] in self?.showQuickOpen(nil) }
            ),
            CommandPaletteItem(
                id: "settings",
                title: L10n.string("Settings…"),
                shortcut: "⌘,",
                action: { [weak self] in self?.showSettings(nil) }
            ),
            CommandPaletteItem(
                id: "preview",
                title: L10n.string("Preview Markdown"),
                shortcut: "",
                action: { [weak self] in self?.toggleMarkdownPreview(nil) }
            ),
            CommandPaletteItem(
                id: "word-wrap",
                title: L10n.string("Word Wrap"),
                shortcut: "",
                action: { [weak self] in self?.toggleWordWrap(nil) }
            ),
            CommandPaletteItem(
                id: "line-numbers",
                title: L10n.string("Line Numbers"),
                shortcut: "",
                action: { [weak self] in self?.toggleLineNumbers(nil) }
            ),
            CommandPaletteItem(
                id: "font-increase",
                title: L10n.string("Bigger"),
                shortcut: "⌘+",
                action: { [weak self] in self?.increaseEditorFontSize(nil) }
            ),
            CommandPaletteItem(
                id: "font-decrease",
                title: L10n.string("Smaller"),
                shortcut: "⌘-",
                action: { [weak self] in self?.decreaseEditorFontSize(nil) }
            ),
            CommandPaletteItem(
                id: "font-reset",
                title: L10n.string("Reset Size"),
                shortcut: "⌘0",
                action: { [weak self] in self?.resetEditorFontSize(nil) }
            ),
            CommandPaletteItem(
                id: "go-to-line",
                title: L10n.string("Go to Line…"),
                shortcut: "⌘⌃L",
                action: { [weak self] in self?.showGoToLine() }
            ),
            CommandPaletteItem(
                id: "document-outline",
                title: L10n.string("Document Outline…"),
                shortcut: "",
                action: { [weak self] in self?.showDocumentOutline(nil) }
            ),
        ]
        items.append(CommandPaletteItem(
            id: "indent-style",
            title: L10n.string("Toggle Indent Style"),
            shortcut: "",
            action: { [weak self] in
                guard let self else { return }
                settings.indentStyle = settings.indentStyle == .spaces ? .tabs : .spaces
            }
        ))
        items.append(CommandPaletteItem(
            id: "ligatures",
            title: L10n.string("Ligatures"),
            shortcut: "",
            action: { [weak self] in self?.toggleFontLigatures(nil) }
        ))
        for theme in EditorThemeChoice.allCases {
            items.append(CommandPaletteItem(
                id: "theme-\(theme.rawValue)",
                title: L10n.format("Use %@ Theme", theme.title),
                shortcut: "",
                action: { [weak self] in self?.settings.editorTheme = theme }
            ))
        }
        for theme in settings.customThemes {
            items.append(CommandPaletteItem(
                id: "custom-theme-\(theme.id)",
                title: L10n.format("Use %@ Theme", theme.name),
                shortcut: "",
                action: { [weak self] in self?.settings.selectEditorTheme(id: theme.id) }
            ))
        }
        for lineEnding in LineEnding.allCases {
            items.append(CommandPaletteItem(
                id: "line-ending-\(lineEnding.rawValue)",
                title: L10n.format("Use %@ Line Ending", lineEnding.localizedName),
                shortcut: "",
                action: { [weak self] in self?.currentDocument?.changeLineEnding(to: lineEnding) }
            ))
        }
        for choice in EncodingMenuChoice.allCases {
            items.append(CommandPaletteItem(
                id: "encoding-\(choice.rawValue)",
                title: L10n.format("Use %@ Encoding", choice.title),
                shortcut: "",
                action: { [weak self] in self?.currentDocument?.changeEncoding(to: choice.detectedEncoding) }
            ))
        }
        return items
    }

    @objc func showDocumentOutline(_ sender: Any?) {
        guard let document = currentDocument else { return }
        let headings = MarkdownOutlineParser.headings(in: document.textStorage.string)
        guard !headings.isEmpty else { return }
        let view = DocumentOutlineView(headings: headings) { [weak self, weak document] heading in
            guard let self, let document else { return }
            let editor = self.findEditorTextView(
                in: document.windowControllers.first?.window?.contentView
            )
            document.windowControllers.first?.window?.makeKeyAndOrderFront(nil)
            editor?.goToLine(heading.line)
            self.outlineWindowController?.close()
        }
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.string("Document Outline")
        window.styleMask = [.titled, .closable, .resizable]
        outlineWindowController = NSWindowController(window: window)
        outlineWindowController?.showWindow(sender)
        window.center()
        window.makeKeyAndOrderFront(sender)
    }

    private func showGoToLine() {
        currentEditorTextView()?.showGoToLinePanel(nil)
    }

    private func currentEditorTextView() -> EditorTextView? {
        func find(in view: NSView?) -> EditorTextView? {
            guard let view else { return nil }
            if let editor = view as? EditorTextView { return editor }
            for child in view.subviews {
                if let editor = find(in: child) { return editor }
            }
            return nil
        }
        return find(in: NSApp.keyWindow?.contentView)
    }

    private func findEditorTextView(in view: NSView?) -> EditorTextView? {
        guard let view else { return nil }
        if let editor = view as? EditorTextView { return editor }
        for child in view.subviews {
            if let editor = findEditorTextView(in: child) { return editor }
        }
        return nil
    }

    private func open(commandLineRequests requests: [TildeOpenRequest]) {
        for request in requests {
            let key = fileKey(for: URL(fileURLWithPath: request.path))
            guard let document = documentController.documents
                .compactMap({ $0 as? TextDocument })
                .first(where: { fileKey(for: $0.fileURL) == key })
            else {
                logger.warning("Dropping command-line metadata because document is not open: \(request.path, privacy: .public)")
                continue
            }
            applyCommandLineRequest(
                request,
                to: document,
                wasAlreadyOpen: true
            )
        }
    }

    private func openCommandLineRequestsAtStartup(_ requests: [TildeOpenRequest]) {
        let urls = requests.flatMap { request -> [URL] in
            let fileURL = URL(fileURLWithPath: request.path)
            guard let metadataURL = commandLineMetadataURL(for: request) else {
                return [fileURL]
            }
            return [fileURL, metadataURL]
        }
        guard let applicationURL = applicationURLForLaunchServices() else {
            // SwiftPM's development executable is not an .app and therefore
            // cannot be routed back through Launch Services. It is not
            // sandboxed, so open the requests directly instead.
            openCommandLineRequestsDirectly(requests)
            return
        }
        NSWorkspace.shared.open(
            urls,
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.logger.error("Could not route startup command-line files: \(error.localizedDescription, privacy: .public)")
                NSApp.presentError(error)
                guard self?.receivedOpenURLs == false else { return }
                self?.restoreLastSessionIfNeeded()
            }
        }
    }

    private func applicationURLForLaunchServices() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            return bundleURL
        }
        return nil
    }

    private func openCommandLineRequestsDirectly(_ requests: [TildeOpenRequest]) {
        for request in requests {
            let url = URL(fileURLWithPath: request.path)
            documentController.openDocument(
                withContentsOf: url,
                display: !request.newWindow,
                completionHandler: { [weak self] document, wasAlreadyOpen, error in
                    if let error {
                        NSApp.presentError(error)
                        return
                    }
                    guard let self, let document = document as? TextDocument else {
                        return
                    }
                    self.applyCommandLineRequest(
                        request,
                        to: document,
                        wasAlreadyOpen: wasAlreadyOpen
                    )
                    self.recentProjects.record(url.deletingLastPathComponent())
                }
            )
        }
    }

    private func applyCommandLineRequest(
        _ request: TildeOpenRequest,
        to document: TextDocument,
        wasAlreadyOpen: Bool
    ) {
        if request.newWindow {
            if wasAlreadyOpen || document.windowControllers.isEmpty {
                document.makeWindowControllers()
            }
            document.windowControllers.forEach { controller in
                controller.window?.tabbingMode = .disallowed
            }
            document.showWindows()
        }
        guard let line = request.line else { return }
        DispatchQueue.main.async {
            let window = document.windowControllers.last?.window
            self.findEditorTextView(in: window?.contentView)?.goToLine(line)
        }
    }

    private func commandLineMetadataURL(for request: TildeOpenRequest) -> URL? {
        guard request.line != nil || request.newWindow else { return nil }
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
        return components.url
    }

    private func fileKey(for url: URL?) -> String {
        url?.standardizedFileURL.path ?? ""
    }

    private static func request(from url: URL) -> TildeOpenRequest? {
        guard url.scheme?.lowercased() == "tilde",
              url.host?.lowercased() == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value
        else { return nil }
        let line = components.queryItems?
            .first(where: { $0.name == "line" })?.value
            .flatMap(Int.init)
        let newWindow = components.queryItems?
            .first(where: { $0.name == "newWindow" })?.value == "1"
        return TildeOpenRequest(path: path, line: line, newWindow: newWindow)
    }

}

public enum TildeApplicationLauncher {
    public static func verifyResources() -> Bool {
        !L10n.string("Editor").isEmpty
    }

    @MainActor
    public static func run() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
