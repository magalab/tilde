import XCTest
@testable import TildeCore

final class LocalizationTests: XCTestCase {
    func testEnglishAndSimplifiedChineseResourcesAreAvailable() {
        XCTAssertTrue(L10n.supportedLanguageCodes.contains("en"))
        XCTAssertTrue(L10n.supportedLanguageCodes.contains {
            $0.caseInsensitiveCompare("zh-Hans") == .orderedSame
        })
        XCTAssertEqual(L10n.string("Settings…", languageCode: "en"), "Settings…")
        XCTAssertEqual(L10n.string("Settings…", languageCode: "zh-Hans"), "设置…")
        XCTAssertEqual(L10n.string("Show line numbers", languageCode: "zh-Hans"), "显示行号")
    }
}
