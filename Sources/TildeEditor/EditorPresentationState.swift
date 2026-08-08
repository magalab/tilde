import Foundation

public struct EditorPresentationState: Equatable, Sendable {
    public let fontSize: Double
    public let fontChoice: EditorFontChoice
    public let fontLigatures: Bool
    public let wordWrap: Bool
    public let showLineNumbers: Bool
    public let tabWidth: Int
    public let indentStyle: IndentStyle

    @MainActor
    public init(settings: EditorSettings) {
        fontSize = settings.fontSize
        fontChoice = settings.fontChoice
        fontLigatures = settings.fontLigatures
        wordWrap = settings.wordWrap
        showLineNumbers = settings.showLineNumbers
        tabWidth = settings.tabWidth
        indentStyle = settings.indentStyle
    }
}
