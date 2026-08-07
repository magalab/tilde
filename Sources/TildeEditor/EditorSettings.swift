import AppKit
import Foundation
import Observation
import TildeCore

public enum IndentStyle: String, CaseIterable, Sendable {
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

public enum PreviewTheme: String, CaseIterable, Sendable {
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

public enum ApplicationTheme: String, CaseIterable, Sendable {
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

public enum WindowOpeningMode: String, CaseIterable, Sendable {
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

public enum DefaultEncodingChoice: String, CaseIterable, Sendable {
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
        static let defaultEncoding = "files.defaultEncoding"
        static let defaultLineEnding = "files.defaultLineEnding"
        static let previewTheme = "markdown.previewTheme"
        static let applicationTheme = "appearance.applicationTheme"
        static let windowOpeningMode = "windows.openingMode"
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

    public var defaultEncoding: DefaultEncodingChoice {
        didSet { defaults.set(defaultEncoding.rawValue, forKey: Key.defaultEncoding) }
    }

    public var defaultLineEnding: LineEnding {
        didSet { defaults.set(defaultLineEnding.rawValue, forKey: Key.defaultLineEnding) }
    }

    public var previewTheme: PreviewTheme {
        didSet { defaults.set(previewTheme.rawValue, forKey: Key.previewTheme) }
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
        defaultEncoding = DefaultEncodingChoice(
            rawValue: defaults.string(forKey: Key.defaultEncoding) ?? ""
        ) ?? .utf8
        defaultLineEnding = LineEnding(
            rawValue: defaults.string(forKey: Key.defaultLineEnding) ?? ""
        ) ?? .lf
        previewTheme = PreviewTheme(
            rawValue: defaults.string(forKey: Key.previewTheme) ?? ""
        ) ?? .system
        applicationTheme = ApplicationTheme(
            rawValue: defaults.string(forKey: Key.applicationTheme) ?? ""
        ) ?? .system
        windowOpeningMode = WindowOpeningMode(
            rawValue: defaults.string(forKey: Key.windowOpeningMode) ?? ""
        ) ?? .maximized
        applyApplicationTheme()
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
