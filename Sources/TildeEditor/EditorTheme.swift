import AppKit
import Foundation
import TildeCore

public struct EditorThemeColor: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            alpha: alpha
        )
    }

    @MainActor
    public var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}

public struct EditorThemePalette: Codable, Hashable, Sendable {
    public let background: EditorThemeColor
    public let foreground: EditorThemeColor
    public let selection: EditorThemeColor
    public let currentLine: EditorThemeColor
    public let lineNumber: EditorThemeColor
    public let divider: EditorThemeColor
    public let heading: EditorThemeColor
    public let marker: EditorThemeColor
    public let code: EditorThemeColor
    public let strong: EditorThemeColor
    public let emphasis: EditorThemeColor
    public let link: EditorThemeColor
    public let quote: EditorThemeColor
    public let deletion: EditorThemeColor
    public let html: EditorThemeColor
    public let error: EditorThemeColor
    public let warning: EditorThemeColor
    public let disabled: EditorThemeColor

    public init(
        background: EditorThemeColor,
        foreground: EditorThemeColor,
        selection: EditorThemeColor,
        currentLine: EditorThemeColor,
        lineNumber: EditorThemeColor,
        divider: EditorThemeColor,
        heading: EditorThemeColor,
        marker: EditorThemeColor,
        code: EditorThemeColor,
        strong: EditorThemeColor,
        emphasis: EditorThemeColor,
        link: EditorThemeColor,
        quote: EditorThemeColor,
        deletion: EditorThemeColor,
        html: EditorThemeColor,
        error: EditorThemeColor = .init(hex: 0xd1242f),
        warning: EditorThemeColor = .init(hex: 0xbf8700),
        disabled: EditorThemeColor = .init(hex: 0x8c959f)
    ) {
        self.background = background
        self.foreground = foreground
        self.selection = selection
        self.currentLine = currentLine
        self.lineNumber = lineNumber
        self.divider = divider
        self.heading = heading
        self.marker = marker
        self.code = code
        self.strong = strong
        self.emphasis = emphasis
        self.link = link
        self.quote = quote
        self.deletion = deletion
        self.html = html
        self.error = error
        self.warning = warning
        self.disabled = disabled
    }

    public static let light = Self(
        background: .init(hex: 0xffffff), foreground: .init(hex: 0x24292f),
        selection: .init(hex: 0xb6d7ff), currentLine: .init(hex: 0xf6f8fa),
        lineNumber: .init(hex: 0x6e7781), divider: .init(hex: 0xd0d7de),
        heading: .init(hex: 0x8250df), marker: .init(hex: 0x6e7781),
        code: .init(hex: 0x953800), strong: .init(hex: 0xcf222e),
        emphasis: .init(hex: 0x0550ae), link: .init(hex: 0x0969da),
        quote: .init(hex: 0x57606a), deletion: .init(hex: 0x82071e),
        html: .init(hex: 0x116329)
    )

    public static let dark = Self(
        background: .init(hex: 0x1f2328), foreground: .init(hex: 0xe6edf3),
        selection: .init(hex: 0x264f78), currentLine: .init(hex: 0x252a30),
        lineNumber: .init(hex: 0x8b949e), divider: .init(hex: 0x444c56),
        heading: .init(hex: 0xd2a8ff), marker: .init(hex: 0x8b949e),
        code: .init(hex: 0xffa657), strong: .init(hex: 0xff7b72),
        emphasis: .init(hex: 0x79c0ff), link: .init(hex: 0x58a6ff),
        quote: .init(hex: 0x8b949e), deletion: .init(hex: 0xff7b72),
        html: .init(hex: 0x7ee787)
    )

    public static let dracula = Self(
        background: .init(hex: 0x282a36), foreground: .init(hex: 0xf8f8f2),
        selection: .init(hex: 0x44475a), currentLine: .init(hex: 0x343746),
        lineNumber: .init(hex: 0x6272a4), divider: .init(hex: 0x44475a),
        heading: .init(hex: 0xbd93f9), marker: .init(hex: 0x6272a4),
        code: .init(hex: 0xffb86c), strong: .init(hex: 0xff79c6),
        emphasis: .init(hex: 0x8be9fd), link: .init(hex: 0x8be9fd),
        quote: .init(hex: 0x6272a4), deletion: .init(hex: 0xff5555),
        html: .init(hex: 0x50fa7b)
    )

    public static let oneDark = Self(
        background: .init(hex: 0x282c34), foreground: .init(hex: 0xabb2bf),
        selection: .init(hex: 0x3e4451), currentLine: .init(hex: 0x2c313c),
        lineNumber: .init(hex: 0x636d83), divider: .init(hex: 0x3e4451),
        heading: .init(hex: 0xc678dd), marker: .init(hex: 0x636d83),
        code: .init(hex: 0xe5c07b), strong: .init(hex: 0xe06c75),
        emphasis: .init(hex: 0x56b6c2), link: .init(hex: 0x61afef),
        quote: .init(hex: 0x5c6370), deletion: .init(hex: 0xe06c75),
        html: .init(hex: 0x98c379)
    )

    public static let solarizedLight = Self(
        background: .init(hex: 0xfdf6e3), foreground: .init(hex: 0x657b83),
        selection: .init(hex: 0xeee8d5), currentLine: .init(hex: 0xf5efdc),
        lineNumber: .init(hex: 0x93a1a1), divider: .init(hex: 0xeee8d5),
        heading: .init(hex: 0x6c71c4), marker: .init(hex: 0x93a1a1),
        code: .init(hex: 0xcb4b16), strong: .init(hex: 0xd33682),
        emphasis: .init(hex: 0x268bd2), link: .init(hex: 0x268bd2),
        quote: .init(hex: 0x839496), deletion: .init(hex: 0xdc322f),
        html: .init(hex: 0x859900)
    )

    public static let solarizedDark = Self(
        background: .init(hex: 0x002b36), foreground: .init(hex: 0x839496),
        selection: .init(hex: 0x073642), currentLine: .init(hex: 0x06313c),
        lineNumber: .init(hex: 0x586e75), divider: .init(hex: 0x073642),
        heading: .init(hex: 0x6c71c4), marker: .init(hex: 0x586e75),
        code: .init(hex: 0xcb4b16), strong: .init(hex: 0xd33682),
        emphasis: .init(hex: 0x2aa198), link: .init(hex: 0x268bd2),
        quote: .init(hex: 0x657b83), deletion: .init(hex: 0xdc322f),
        html: .init(hex: 0x859900)
    )

    public static let gruvboxDark = Self(
        background: .init(hex: 0x282828), foreground: .init(hex: 0xebdbb2),
        selection: .init(hex: 0x504945), currentLine: .init(hex: 0x32302f),
        lineNumber: .init(hex: 0x928374), divider: .init(hex: 0x504945),
        heading: .init(hex: 0xd3869b), marker: .init(hex: 0x928374),
        code: .init(hex: 0xfabd2f), strong: .init(hex: 0xfb4934),
        emphasis: .init(hex: 0x83a598), link: .init(hex: 0x8ec07c),
        quote: .init(hex: 0xa89984), deletion: .init(hex: 0xfb4934),
        html: .init(hex: 0xb8bb26)
    )

    public static let nord = Self(
        background: .init(hex: 0x2e3440), foreground: .init(hex: 0xd8dee9),
        selection: .init(hex: 0x434c5e), currentLine: .init(hex: 0x353c4a),
        lineNumber: .init(hex: 0x7b88a1), divider: .init(hex: 0x434c5e),
        heading: .init(hex: 0x81a1c1), marker: .init(hex: 0x81a1c1),
        code: .init(hex: 0xebcb8b), strong: .init(hex: 0x88c0d0),
        emphasis: .init(hex: 0xb48ead), link: .init(hex: 0x8fbcbb),
        quote: .init(hex: 0x81a1c1), deletion: .init(hex: 0xbf616a),
        html: .init(hex: 0xa3be8c)
    )

    public static let monokai = Self(
        background: .init(hex: 0x272822), foreground: .init(hex: 0xf8f8f2),
        selection: .init(hex: 0x49483e), currentLine: .init(hex: 0x30312b),
        lineNumber: .init(hex: 0x90908a), divider: .init(hex: 0x49483e),
        heading: .init(hex: 0xae81ff), marker: .init(hex: 0x90908a),
        code: .init(hex: 0xe6db74), strong: .init(hex: 0xf92672),
        emphasis: .init(hex: 0x66d9ef), link: .init(hex: 0xa6e22e),
        quote: .init(hex: 0x75715e), deletion: .init(hex: 0xf92672),
        html: .init(hex: 0xa6e22e)
    )
}

public struct EditorThemeDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let palette: EditorThemePalette

    public init(id: String, name: String, palette: EditorThemePalette) throws {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty,
              normalizedID.count <= 80,
              normalizedID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
              !normalizedName.isEmpty,
              normalizedName.count <= 120
        else {
            throw EditorThemeError.invalidMetadata
        }
        guard palette.colorsAreValid else {
            throw EditorThemeError.invalidColor
        }
        self.id = normalizedID
        self.name = normalizedName
        self.palette = palette
    }
}

public enum EditorThemeError: LocalizedError, Equatable, Sendable {
    case invalidMetadata
    case invalidColor
    case unsupportedVersion

    public var errorDescription: String? {
        switch self {
        case .invalidMetadata: "Theme id or name is invalid."
        case .invalidColor: "Theme contains a color outside the 0...1 range."
        case .unsupportedVersion: "This theme file version is not supported."
        }
    }
}

private extension EditorThemePalette {
    var colorsAreValid: Bool {
        [background, foreground, selection, currentLine, lineNumber, divider,
         heading, marker, code, strong, emphasis, link, quote, deletion, html,
         error, warning, disabled].allSatisfy { color in
            [color.red, color.green, color.blue, color.alpha].allSatisfy {
                $0.isFinite && (0...1).contains($0)
            }
        }
    }
}

public enum EditorThemeChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark
    case dracula
    case oneDark
    case solarizedLight
    case solarizedDark
    case gruvboxDark
    case nord
    case monokai

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: L10n.string("System")
        case .light: L10n.string("Light")
        case .dark: L10n.string("Dark")
        case .dracula: "Dracula"
        case .oneDark: "One Dark"
        case .solarizedLight: "Solarized Light"
        case .solarizedDark: "Solarized Dark"
        case .gruvboxDark: "Gruvbox Dark"
        case .nord: "Nord"
        case .monokai: "Monokai"
        }
    }

    @MainActor
    public var palette: EditorThemePalette {
        switch self {
        case .system:
            NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .dark
                : .light
        case .light: .light
        case .dark: .dark
        case .dracula: .dracula
        case .oneDark: .oneDark
        case .solarizedLight: .solarizedLight
        case .solarizedDark: .solarizedDark
        case .gruvboxDark: .gruvboxDark
        case .nord: .nord
        case .monokai: .monokai
        }
    }
}
