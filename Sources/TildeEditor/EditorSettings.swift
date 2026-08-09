import AppKit
import Foundation
import Observation
import TildeCore

public enum IndentStyle: String, CaseIterable, Codable, Sendable {
    case tabs
    case spaces
}

public struct EditorFontChoice: Identifiable, Hashable, Sendable {
    private static let systemMonospacedID = "systemMonospaced"

    public let id: String
    public let title: String
    fileprivate let familyName: String?

    public static let systemMonospaced = EditorFontChoice(
        id: systemMonospacedID,
        title: L10n.string("System Monospaced"),
        familyName: nil
    )

    @MainActor
    fileprivate static func installedFonts() -> [EditorFontChoice] {
        let families = Set(NSFontManager.shared.availableFontFamilies)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return [.systemMonospaced] + families.map { family in
            EditorFontChoice(
                id: "family:\(family)",
                title: family,
                familyName: family
            )
        }
    }

    fileprivate static func restore(
        persistedID: String?,
        from availableFonts: [EditorFontChoice]
    ) -> EditorFontChoice {
        guard let persistedID else { return .systemMonospaced }
        if let exactMatch = availableFonts.first(where: { $0.id == persistedID }) {
            return exactMatch
        }

        let legacyFamily: String? = switch persistedID {
        case "menlo": "Menlo"
        case "monaco": "Monaco"
        case "courier": "Courier"
        default: nil
        }
        guard let legacyFamily else { return .systemMonospaced }
        return availableFonts.first(where: { $0.familyName == legacyFamily }) ?? .systemMonospaced
    }
}

public enum PreviewTheme: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    public var title: String {
        switch self {
        case .system: L10n.string("System")
        case .light: L10n.string("Light")
        case .dark: L10n.string("Dark")
        }
    }
}

public enum ApplicationTheme: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    public var title: String {
        switch self {
        case .system: L10n.string("System")
        case .light: L10n.string("Light")
        case .dark: L10n.string("Dark")
        }
    }

    fileprivate var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

public enum WindowOpeningMode: String, CaseIterable, Codable, Sendable {
    case normal
    case maximized
    case fullScreen

    public var title: String {
        switch self {
        case .normal: L10n.string("Normal")
        case .maximized: L10n.string("Maximized")
        case .fullScreen: L10n.string("Full Screen")
        }
    }
}

public enum DefaultEncodingChoice: String, CaseIterable, Codable, Sendable {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian

    public var title: String {
        switch self {
        case .utf8: L10n.string("UTF-8")
        case .utf16LittleEndian: L10n.string("UTF-16 Little Endian")
        case .utf16BigEndian: L10n.string("UTF-16 Big Endian")
        }
    }

    public var detectedEncoding: DetectedEncoding {
        switch self {
        case .utf8:
            .newDocumentUTF8
        case .utf16LittleEndian:
            DetectedEncoding(encoding: .utf16LittleEndian, byteOrder: .littleEndian, bomPolicy: .present, confidence: .certain)
        case .utf16BigEndian:
            DetectedEncoding(encoding: .utf16BigEndian, byteOrder: .bigEndian, bomPolicy: .present, confidence: .certain)
        }
    }
}

public struct EditorSettingsSnapshot: Codable, Equatable, Sendable {
    public var fontSize: Double
    public var fontChoiceID: String
    public var fontLigatures: Bool
    public var wordWrap: Bool
    public var showLineNumbers: Bool
    public var tabWidth: Int
    public var indentStyle: IndentStyle
    public var editorTheme: EditorThemeChoice
    public var defaultEncoding: DefaultEncodingChoice
    public var defaultLineEnding: LineEnding
    public var previewTheme: PreviewTheme
    public var allowsRemoteImages: Bool
    public var applicationTheme: ApplicationTheme
    public var windowOpeningMode: WindowOpeningMode

    private enum CodingKeys: String, CodingKey {
        case fontSize, fontChoiceID, fontLigatures, wordWrap, showLineNumbers, tabWidth
        case indentStyle, editorTheme, defaultEncoding, defaultLineEnding, previewTheme
        case allowsRemoteImages, applicationTheme, windowOpeningMode
    }

    public init(
        fontSize: Double,
        fontChoiceID: String,
        fontLigatures: Bool,
        wordWrap: Bool,
        showLineNumbers: Bool,
        tabWidth: Int,
        indentStyle: IndentStyle,
        editorTheme: EditorThemeChoice,
        defaultEncoding: DefaultEncodingChoice,
        defaultLineEnding: LineEnding,
        previewTheme: PreviewTheme,
        allowsRemoteImages: Bool,
        applicationTheme: ApplicationTheme,
        windowOpeningMode: WindowOpeningMode
    ) {
        self.fontSize = fontSize
        self.fontChoiceID = fontChoiceID
        self.fontLigatures = fontLigatures
        self.wordWrap = wordWrap
        self.showLineNumbers = showLineNumbers
        self.tabWidth = tabWidth
        self.indentStyle = indentStyle
        self.editorTheme = editorTheme
        self.defaultEncoding = defaultEncoding
        self.defaultLineEnding = defaultLineEnding
        self.previewTheme = previewTheme
        self.allowsRemoteImages = allowsRemoteImages
        self.applicationTheme = applicationTheme
        self.windowOpeningMode = windowOpeningMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        fontChoiceID = try container.decode(String.self, forKey: .fontChoiceID)
        fontLigatures = try container.decode(Bool.self, forKey: .fontLigatures)
        wordWrap = try container.decode(Bool.self, forKey: .wordWrap)
        showLineNumbers = try container.decode(Bool.self, forKey: .showLineNumbers)
        tabWidth = try container.decode(Int.self, forKey: .tabWidth)
        indentStyle = try container.decode(IndentStyle.self, forKey: .indentStyle)
        editorTheme = try container.decode(EditorThemeChoice.self, forKey: .editorTheme)
        defaultEncoding = try container.decode(DefaultEncodingChoice.self, forKey: .defaultEncoding)
        defaultLineEnding = try container.decode(LineEnding.self, forKey: .defaultLineEnding)
        previewTheme = try container.decode(PreviewTheme.self, forKey: .previewTheme)
        allowsRemoteImages = try container.decodeIfPresent(Bool.self, forKey: .allowsRemoteImages) ?? false
        applicationTheme = try container.decode(ApplicationTheme.self, forKey: .applicationTheme)
        windowOpeningMode = try container.decode(WindowOpeningMode.self, forKey: .windowOpeningMode)
    }
}

public struct EditorThemeFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public let version: Int
    public let theme: EditorThemeDefinition

    public init(theme: EditorThemeDefinition, version: Int = currentVersion) throws {
        guard version == Self.currentVersion else {
            throw EditorThemeError.unsupportedVersion
        }
        self.version = version
        self.theme = theme
    }
}

@MainActor
@Observable
public final class EditorSettings {
    private enum Key {
        static let fontSize = "editor.fontSize"
        static let fontChoice = "editor.fontChoice"
        static let fontLigatures = "editor.fontLigatures"
        static let wordWrap = "editor.wordWrap"
        static let showLineNumbers = "editor.showLineNumbers"
        static let tabWidth = "editor.tabWidth"
        static let indentStyle = "editor.indentStyle"
        static let editorTheme = "editor.theme"
        static let defaultEncoding = "files.defaultEncoding"
        static let defaultLineEnding = "files.defaultLineEnding"
        static let previewTheme = "markdown.previewTheme"
        static let allowsRemoteImages = "markdown.allowsRemoteImages"
        static let applicationTheme = "appearance.applicationTheme"
        static let windowOpeningMode = "windows.openingMode"
        static let customThemes = "editor.customThemes"
        static let selectedCustomTheme = "editor.selectedCustomTheme"
    }

    private let defaults: UserDefaults

    public let availableFonts: [EditorFontChoice]

    public private(set) var fontSize: Double

    public var fontChoice: EditorFontChoice {
        didSet { defaults.set(fontChoice.id, forKey: Key.fontChoice) }
    }

    public var fontLigatures: Bool {
        didSet { defaults.set(fontLigatures, forKey: Key.fontLigatures) }
    }

    public var wordWrap: Bool {
        didSet { defaults.set(wordWrap, forKey: Key.wordWrap) }
    }

    public var showLineNumbers: Bool {
        didSet { defaults.set(showLineNumbers, forKey: Key.showLineNumbers) }
    }

    public private(set) var tabWidth: Int

    public var indentStyle: IndentStyle {
        didSet { defaults.set(indentStyle.rawValue, forKey: Key.indentStyle) }
    }

    public var editorTheme: EditorThemeChoice {
        didSet {
            defaults.set(editorTheme.rawValue, forKey: Key.editorTheme)
            selectedCustomThemeID = nil
            defaults.removeObject(forKey: Key.selectedCustomTheme)
        }
    }

    public private(set) var customThemes: [EditorThemeDefinition]
    public private(set) var selectedCustomThemeID: String?

    public var activeEditorThemeID: String {
        selectedCustomThemeID ?? editorTheme.rawValue
    }

    @MainActor
    public var editorThemePalette: EditorThemePalette {
        if let selectedCustomThemeID,
           let customTheme = customThemes.first(where: { $0.id == selectedCustomThemeID }) {
            return customTheme.palette
        }
        return editorTheme.palette
    }

    public var defaultEncoding: DefaultEncodingChoice {
        didSet { defaults.set(defaultEncoding.rawValue, forKey: Key.defaultEncoding) }
    }

    public var defaultLineEnding: LineEnding {
        didSet { defaults.set(defaultLineEnding.rawValue, forKey: Key.defaultLineEnding) }
    }

    public var previewTheme: PreviewTheme {
        didSet { defaults.set(previewTheme.rawValue, forKey: Key.previewTheme) }
    }

    public var allowsRemoteImages: Bool {
        didSet { defaults.set(allowsRemoteImages, forKey: Key.allowsRemoteImages) }
    }

    public var applicationTheme: ApplicationTheme {
        didSet {
            defaults.set(applicationTheme.rawValue, forKey: Key.applicationTheme)
            applyApplicationTheme()
        }
    }

    public var windowOpeningMode: WindowOpeningMode {
        didSet { defaults.set(windowOpeningMode.rawValue, forKey: Key.windowOpeningMode) }
    }

    public var font: NSFont {
        guard let familyName = fontChoice.familyName,
              let font = NSFont(
                  descriptor: NSFontDescriptor(fontAttributes: [.family: familyName]),
                  size: fontSize
              )
        else { return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular) }
        return font
    }

    public func increaseFontSize() {
        setFontSize(fontSize + 1)
    }

    public func decreaseFontSize() {
        setFontSize(fontSize - 1)
    }

    public func resetFontSize() {
        setFontSize(13)
    }

    public func setFontSize(_ value: Double) {
        let clamped = Self.clampFontSize(value)
        guard fontSize != clamped else { return }
        fontSize = clamped
        defaults.set(clamped, forKey: Key.fontSize)
    }

    public func setTabWidth(_ value: Int) {
        let clamped = Self.clampTabWidth(value)
        guard tabWidth != clamped else { return }
        tabWidth = clamped
        defaults.set(clamped, forKey: Key.tabWidth)
    }

    public func selectEditorTheme(id: String) {
        if let builtIn = EditorThemeChoice(rawValue: id) {
            selectedCustomThemeID = nil
            defaults.removeObject(forKey: Key.selectedCustomTheme)
            editorTheme = builtIn
            return
        }
        guard customThemes.contains(where: { $0.id == id }) else { return }
        selectedCustomThemeID = id
        defaults.set(id, forKey: Key.selectedCustomTheme)
    }

    public func exportThemeData(id: String? = nil) throws -> Data {
        let theme: EditorThemeDefinition
        if let id {
            guard let found = customThemes.first(where: { $0.id == id }) else {
                throw EditorThemeError.invalidMetadata
            }
            theme = found
        } else if let selectedCustomThemeID,
                  let found = customThemes.first(where: { $0.id == selectedCustomThemeID }) {
            theme = found
        } else {
            let builtIn = editorTheme
            theme = try EditorThemeDefinition(
                id: builtIn.rawValue,
                name: builtIn.title,
                palette: builtIn.palette
            )
        }
        let file = try EditorThemeFile(theme: theme)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    @discardableResult
    public func importThemeData(_ data: Data) throws -> EditorThemeDefinition {
        let file = try JSONDecoder().decode(EditorThemeFile.self, from: data)
        let theme = try EditorThemeDefinition(
            id: file.theme.id,
            name: file.theme.name,
            palette: file.theme.palette
        )
        guard EditorThemeChoice(rawValue: theme.id) == nil else {
            throw EditorThemeError.invalidMetadata
        }
        customThemes.removeAll { $0.id == theme.id }
        customThemes.append(theme)
        customThemes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistCustomThemes()
        selectEditorTheme(id: theme.id)
        return theme
    }

    public func removeCustomTheme(id: String) {
        guard customThemes.contains(where: { $0.id == id }) else { return }
        customThemes.removeAll { $0.id == id }
        persistCustomThemes()
        if selectedCustomThemeID == id {
            selectEditorTheme(id: EditorThemeChoice.system.rawValue)
        }
    }

    public func exportSnapshotData() throws -> Data {
        let snapshot = EditorSettingsSnapshot(
            fontSize: fontSize,
            fontChoiceID: fontChoice.id,
            fontLigatures: fontLigatures,
            wordWrap: wordWrap,
            showLineNumbers: showLineNumbers,
            tabWidth: tabWidth,
            indentStyle: indentStyle,
            editorTheme: editorTheme,
            defaultEncoding: defaultEncoding,
            defaultLineEnding: defaultLineEnding,
            previewTheme: previewTheme,
            allowsRemoteImages: allowsRemoteImages,
            applicationTheme: applicationTheme,
            windowOpeningMode: windowOpeningMode
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public func importSnapshotData(_ data: Data) throws {
        let snapshot = try JSONDecoder().decode(EditorSettingsSnapshot.self, from: data)
        setFontSize(snapshot.fontSize)
        if let font = availableFonts.first(where: { $0.id == snapshot.fontChoiceID }) {
            fontChoice = font
        }
        fontLigatures = snapshot.fontLigatures
        wordWrap = snapshot.wordWrap
        showLineNumbers = snapshot.showLineNumbers
        setTabWidth(snapshot.tabWidth)
        indentStyle = snapshot.indentStyle
        editorTheme = snapshot.editorTheme
        defaultEncoding = snapshot.defaultEncoding
        defaultLineEnding = snapshot.defaultLineEnding
        previewTheme = snapshot.previewTheme
        allowsRemoteImages = snapshot.allowsRemoteImages
        applicationTheme = snapshot.applicationTheme
        windowOpeningMode = snapshot.windowOpeningMode
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        availableFonts = EditorFontChoice.installedFonts()
        let storedFontSize = defaults.double(forKey: Key.fontSize)
        fontSize = storedFontSize == 0 ? 13 : Self.clampFontSize(storedFontSize)
        fontChoice = EditorFontChoice.restore(
            persistedID: defaults.string(forKey: Key.fontChoice),
            from: availableFonts
        )
        fontLigatures = defaults.object(forKey: Key.fontLigatures) as? Bool ?? false
        wordWrap = defaults.object(forKey: Key.wordWrap) as? Bool ?? true
        showLineNumbers = defaults.object(forKey: Key.showLineNumbers) as? Bool ?? false
        let storedTabWidth = defaults.integer(forKey: Key.tabWidth)
        tabWidth = storedTabWidth == 0 ? 2 : Self.clampTabWidth(storedTabWidth)
        indentStyle = IndentStyle(
            rawValue: defaults.string(forKey: Key.indentStyle) ?? ""
        ) ?? .spaces
        editorTheme = EditorThemeChoice(
            rawValue: defaults.string(forKey: Key.editorTheme) ?? ""
        ) ?? .system
        defaultEncoding = DefaultEncodingChoice(
            rawValue: defaults.string(forKey: Key.defaultEncoding) ?? ""
        ) ?? .utf8
        defaultLineEnding = LineEnding(
            rawValue: defaults.string(forKey: Key.defaultLineEnding) ?? ""
        ) ?? .lf
        previewTheme = PreviewTheme(
            rawValue: defaults.string(forKey: Key.previewTheme) ?? ""
        ) ?? .system
        allowsRemoteImages = defaults.object(forKey: Key.allowsRemoteImages) as? Bool ?? false
        applicationTheme = ApplicationTheme(
            rawValue: defaults.string(forKey: Key.applicationTheme) ?? ""
        ) ?? .system
        windowOpeningMode = WindowOpeningMode(
            rawValue: defaults.string(forKey: Key.windowOpeningMode) ?? ""
        ) ?? .maximized
        customThemes = Self.loadCustomThemes(from: defaults)
        selectedCustomThemeID = defaults.string(forKey: Key.selectedCustomTheme)
        if let selectedCustomThemeID,
           !customThemes.contains(where: { $0.id == selectedCustomThemeID }) {
            self.selectedCustomThemeID = nil
        }
        applyApplicationTheme()
    }

    private func persistCustomThemes() {
        guard let data = try? JSONEncoder().encode(customThemes) else { return }
        defaults.set(data, forKey: Key.customThemes)
    }

    private static func loadCustomThemes(from defaults: UserDefaults) -> [EditorThemeDefinition] {
        guard let data = defaults.data(forKey: Key.customThemes),
              let themes = try? JSONDecoder().decode([EditorThemeDefinition].self, from: data)
        else { return [] }
        return themes.compactMap { theme in
            try? EditorThemeDefinition(
                id: theme.id,
                name: theme.name,
                palette: theme.palette
            )
        }
    }

    private func applyApplicationTheme() {
        NSApplication.shared.appearance = applicationTheme.appearance
    }

    private static func clampFontSize(_ value: Double) -> Double {
        guard value.isFinite else { return 13 }
        return min(max(value, 8), 72)
    }

    private static func clampTabWidth(_ value: Int) -> Int {
        min(max(value, 1), 16)
    }
}
