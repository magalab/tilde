import AppKit
import Foundation
import XCTest
@testable import TildeCore
@testable import TildeEditor

@MainActor
final class EditorSettingsTests: XCTestCase {
    func testFileDefaultsPersistAndExposeEncodingMetadata() throws {
        let previousAppearance = NSApplication.shared.appearance
        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            NSApplication.shared.appearance = previousAppearance
        }
        let settings = EditorSettings(defaults: defaults)

        settings.defaultEncoding = .utf16BigEndian
        settings.defaultLineEnding = .crlf
        let menlo = try XCTUnwrap(settings.availableFonts.first(where: { $0.title == "Menlo" }))
        settings.fontChoice = menlo
        settings.fontLigatures = true
        settings.showLineNumbers = true
        settings.editorTheme = .dracula
        settings.previewTheme = .dark
        settings.allowsRemoteImages = true
        settings.applicationTheme = .dark
        settings.windowOpeningMode = .fullScreen

        let restored = EditorSettings(defaults: defaults)
        XCTAssertEqual(restored.defaultEncoding, .utf16BigEndian)
        XCTAssertEqual(restored.defaultEncoding.detectedEncoding.byteOrder, .bigEndian)
        XCTAssertEqual(restored.defaultLineEnding, .crlf)
        XCTAssertEqual(restored.fontChoice, menlo)
        XCTAssertTrue(restored.fontLigatures)
        XCTAssertTrue(restored.showLineNumbers)
        XCTAssertEqual(restored.editorTheme, .dracula)
        XCTAssertEqual(restored.previewTheme, .dark)
        XCTAssertTrue(restored.allowsRemoteImages)
        XCTAssertEqual(restored.applicationTheme, .dark)
        XCTAssertEqual(restored.windowOpeningMode, .fullScreen)
        XCTAssertEqual(NSApplication.shared.appearance?.name, .darkAqua)
    }

    func testInstalledFontFamiliesAreAvailableAndLegacyChoiceMigrates() throws {
        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("menlo", forKey: "editor.fontChoice")

        let settings = EditorSettings(defaults: defaults)
        XCTAssertGreaterThan(settings.availableFonts.count, 4)
        XCTAssertEqual(settings.availableFonts.first, .systemMonospaced)
        XCTAssertEqual(settings.fontChoice.title, "Menlo")
        XCTAssertEqual(settings.font.familyName, "Menlo")
    }

    func testNewSettingsUseTwoSpaceTabWidthAndExcludeBOMEncodingChoice() {
        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = EditorSettings(defaults: defaults)
        XCTAssertEqual(settings.tabWidth, 2)
        XCTAssertFalse(settings.fontLigatures)
        XCTAssertFalse(settings.showLineNumbers)
        XCTAssertEqual(settings.applicationTheme, .system)
        XCTAssertEqual(settings.windowOpeningMode, .maximized)
        XCTAssertEqual(
            DefaultEncodingChoice.allCases,
            [.utf8, .utf16LittleEndian, .utf16BigEndian]
        )

        defaults.set("utf8BOM", forKey: "files.defaultEncoding")
        XCTAssertEqual(EditorSettings(defaults: defaults).defaultEncoding, .utf8)
    }

    func testInvalidStoredDisplayValuesAreClamped() {
        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(500, forKey: "editor.fontSize")
        defaults.set(-5, forKey: "editor.tabWidth")

        let settings = EditorSettings(defaults: defaults)
        XCTAssertEqual(settings.fontSize, 72)
        XCTAssertEqual(settings.tabWidth, 1)
    }

    func testLiveDisplayValuesClampWithoutRecursiveObservationMutation() {
        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = EditorSettings(defaults: defaults)

        settings.setFontSize(500)
        settings.setTabWidth(-5)
        XCTAssertEqual(settings.fontSize, 72)
        XCTAssertEqual(settings.tabWidth, 1)

        for _ in 0..<100 {
            settings.increaseFontSize()
        }
        XCTAssertEqual(settings.fontSize, 72)
        for _ in 0..<100 {
            settings.decreaseFontSize()
        }
        XCTAssertEqual(settings.fontSize, 8)
        settings.resetFontSize()
        XCTAssertEqual(settings.fontSize, 13)
    }

    func testBuiltInEditorThemesProvideCompletePalettes() {
        for theme in EditorThemeChoice.allCases {
            let palette = theme.palette
            XCTAssertGreaterThanOrEqual(palette.background.alpha, 0)
            XCTAssertLessThanOrEqual(palette.background.alpha, 1)
            XCTAssertGreaterThanOrEqual(palette.foreground.alpha, 0)
            XCTAssertLessThanOrEqual(palette.foreground.alpha, 1)
        }
    }

    func testSettingsSnapshotRoundTripsDisplayAndFilePreferences() throws {
        let suiteName = "TildeEditorTests-(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = EditorSettings(defaults: defaults)
        settings.setFontSize(21)
        settings.setTabWidth(8)
        settings.indentStyle = .tabs
        settings.editorTheme = .nord
        settings.defaultEncoding = .utf16LittleEndian
        settings.defaultLineEnding = .cr
        settings.previewTheme = .dark
        settings.allowsRemoteImages = true

        let data = try settings.exportSnapshotData()
        let restoredDefaults = UserDefaults(suiteName: "TildeEditorTests-\(UUID().uuidString)")!
        let restored = EditorSettings(defaults: restoredDefaults)
        try restored.importSnapshotData(data)

        XCTAssertEqual(restored.fontSize, 21)
        XCTAssertEqual(restored.tabWidth, 8)
        XCTAssertEqual(restored.indentStyle, .tabs)
        XCTAssertEqual(restored.editorTheme, .nord)
        XCTAssertEqual(restored.defaultEncoding, .utf16LittleEndian)
        XCTAssertEqual(restored.defaultLineEnding, .cr)
        XCTAssertEqual(restored.previewTheme, .dark)
        XCTAssertTrue(restored.allowsRemoteImages)
    }

    func testCustomThemeImportsPersistsSelectsAndExports() throws {
        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = EditorSettings(defaults: defaults)
        let definition = try EditorThemeDefinition(
            id: "test-theme",
            name: "Test Theme",
            palette: .dark
        )
        let input = try JSONEncoder().encode(try EditorThemeFile(theme: definition))

        try settings.importThemeData(input)
        XCTAssertEqual(settings.activeEditorThemeID, "test-theme")
        XCTAssertEqual(settings.editorThemePalette, .dark)

        let restored = EditorSettings(defaults: defaults)
        XCTAssertEqual(restored.customThemes, [definition])
        XCTAssertEqual(restored.activeEditorThemeID, "test-theme")
        let exported = try restored.exportThemeData()
        XCTAssertEqual(try JSONDecoder().decode(EditorThemeFile.self, from: exported).theme, definition)

        restored.removeCustomTheme(id: "test-theme")
        XCTAssertNil(restored.selectedCustomThemeID)
        XCTAssertEqual(restored.activeEditorThemeID, EditorThemeChoice.system.rawValue)
    }

    func testCustomThemeRejectsInvalidMetadataAndBuiltInIDs() throws {
        let invalid = EditorThemePalette(
            background: .init(red: 2, green: 0, blue: 0),
            foreground: EditorThemePalette.dark.foreground,
            selection: EditorThemePalette.dark.selection,
            currentLine: EditorThemePalette.dark.currentLine,
            lineNumber: EditorThemePalette.dark.lineNumber,
            divider: EditorThemePalette.dark.divider,
            heading: EditorThemePalette.dark.heading,
            marker: EditorThemePalette.dark.marker,
            code: EditorThemePalette.dark.code,
            strong: EditorThemePalette.dark.strong,
            emphasis: EditorThemePalette.dark.emphasis,
            link: EditorThemePalette.dark.link,
            quote: EditorThemePalette.dark.quote,
            deletion: EditorThemePalette.dark.deletion,
            html: EditorThemePalette.dark.html
        )
        XCTAssertThrowsError(try EditorThemeDefinition(id: "bad id", name: "", palette: invalid))

        let suiteName = "TildeEditorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = EditorSettings(defaults: defaults)
        let builtIn = try JSONEncoder().encode(
            try EditorThemeFile(
                theme: EditorThemeDefinition(id: "dark", name: "Custom", palette: .dark)
            )
        )
        XCTAssertThrowsError(try settings.importThemeData(builtIn))
    }
}
