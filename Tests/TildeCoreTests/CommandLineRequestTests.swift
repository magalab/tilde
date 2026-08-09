import Foundation
import XCTest
@testable import TildeCore

final class CommandLineRequestTests: XCTestCase {
    func testParsesMultipleFilesAndLineSyntax() {
        let requests = TildeCommandLine.parse(
            ["README.md:12", "--new-window", "notes.txt", "--line=7", "source.swift"],
            currentDirectory: URL(fileURLWithPath: "/tmp/project")
        )

        XCTAssertEqual(requests, [
            TildeOpenRequest(path: "/tmp/project/README.md", line: 12),
            TildeOpenRequest(path: "/tmp/project/notes.txt", newWindow: true),
            TildeOpenRequest(path: "/tmp/project/source.swift", line: 7, newWindow: true),
        ])
    }

    func testParsesExplicitLineOptionAndStopsAtDoubleDash() {
        let requests = TildeCommandLine.parse(
            ["--line", "20", "--", "--literal.txt"],
            currentDirectory: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(requests, [
            TildeOpenRequest(path: "/tmp/--literal.txt", line: 20),
        ])
    }

    func testIgnoresInvalidLineValuesAndProcessSessionArgument() {
        let requests = TildeCommandLine.parse(
            ["--line", "0", "-psn_0_12345", "file.txt"],
            currentDirectory: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(requests, [
            TildeOpenRequest(path: "/tmp/file.txt"),
        ])
    }
}
