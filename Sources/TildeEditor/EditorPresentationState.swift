import Foundation
import TildeCore

public struct EditorPresentationState: Equatable, Sendable {
    public let fontSize: Double
    public let fontChoice: EditorFontChoice
    public let fontLigatures: Bool
    public let wordWrap: Bool
    public let showLineNumbers: Bool
    public let tabWidth: Int
    public let indentStyle: IndentStyle
    public let editorThemeID: String
    public let editorThemePalette: EditorThemePalette
    public let largeFileDisposition: LargeFileDisposition

    @MainActor
    public init(
        settings: EditorSettings,
        largeFileDisposition: LargeFileDisposition = .standard
    ) {
        fontSize = settings.fontSize
        fontChoice = settings.fontChoice
        fontLigatures = settings.fontLigatures
        wordWrap = settings.wordWrap
        showLineNumbers = settings.showLineNumbers
        tabWidth = settings.tabWidth
        indentStyle = settings.indentStyle
        editorThemeID = settings.activeEditorThemeID
        editorThemePalette = settings.editorThemePalette
        self.largeFileDisposition = largeFileDisposition
    }
}
