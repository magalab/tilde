import Foundation

struct EditorPresentationState: Equatable {
    let fontSize: Double
    let fontChoice: EditorFontChoice
    let fontLigatures: Bool
    let wordWrap: Bool
    let showLineNumbers: Bool
    let tabWidth: Int
    let indentStyle: IndentStyle

    @MainActor
    init(settings: EditorSettings) {
        fontSize = settings.fontSize
        fontChoice = settings.fontChoice
        fontLigatures = settings.fontLigatures
        wordWrap = settings.wordWrap
        showLineNumbers = settings.showLineNumbers
        tabWidth = settings.tabWidth
        indentStyle = settings.indentStyle
    }
}
