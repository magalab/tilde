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
        settings.previewTheme = .dark
        settings.applicationTheme = .dark
        settings.windowOpeningMode = .fullScreen

        let restored = EditorSettings(defaults: defaults)
        XCTAssertEqual(restored.defaultEncoding, .utf16BigEndian)
        XCTAssertEqual(restored.defaultEncoding.detectedEncoding.byteOrder, .bigEndian)
        XCTAssertEqual(restored.defaultLineEnding, .crlf)
        XCTAssertEqual(restored.fontChoice, menlo)
        XCTAssertTrue(restored.fontLigatures)
        XCTAssertTrue(restored.showLineNumbers)
        XCTAssertEqual(restored.previewTheme, .dark)
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
}
