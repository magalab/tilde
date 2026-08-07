import AppKit
import XCTest
@testable import TildeEditor

@MainActor
final class LineNumberRulerViewTests: XCTestCase {
    func testRulerGrowsOnlyWhenLineNumberNeedsMoreSpace() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let shortDocument = LineNumberRulerView.requiredThickness(
            forLineCount: 9,
            font: font
        )
        let longDocument = LineNumberRulerView.requiredThickness(
            forLineCount: 999_999,
            font: font
        )

        XCTAssertGreaterThanOrEqual(shortDocument, 36)
        XCTAssertGreaterThan(longDocument, shortDocument)
    }
}
