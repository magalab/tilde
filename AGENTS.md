# Repository Guidelines

## Project Structure & Module Organization

Tilde is a Swift 6, macOS 15+ plain-text editor. Swift Package Manager is the source of truth for code, dependencies, products, and tests. Keep logic in `Sources/`:

- `Sources/TildeCore`: encoding, line endings, localization, and shared policy.
- `Sources/TildeDocument`: `NSDocument` model and external-change handling.
- `Sources/TildeEditor`: TextKit editor UI, settings, line numbers, and highlighting.
- `Sources/TildeMarkdown`: Markdown preview and attachment loading.
- `Sources/TildeQuickLook`: extension-safe Quick Look rendering.
- `Sources/TildeApplication` and `Sources/TildeApp`: app composition and executable entry point.

Tests mirror targets under `Tests/`. Fixtures live in `Tests/Fixtures`. `Host/` is only the thin Xcode packaging layer for the `.app` and Quick Look `.appex`; do not move feature logic there.

## Build, Test, and Development Commands

- `swift package resolve`: resolve pinned dependencies.
- `swift build`: build all SwiftPM products.
- `swift test`: run the XCTest suite.
- `swift run Tilde`: launch the development executable.
- `scripts/verify-host.sh Debug`: run package tests, build the host app, and validate bundle layout, signing, localization, sandboxing, and entitlements.
- `scripts/run-benchmarks.sh`: run performance checks for loading, editing, Markdown rendering, and memory use.
- `scripts/build-dmg.sh Release`: create a local release DMG after verification.

## Coding Style & Naming Conventions

Follow existing Swift style: 4-space indentation, `PascalCase` types, `camelCase` methods and properties, and explicit access control for public APIs. Prefer small target-local types over cross-module dependencies. Keep extension-safe Quick Look code isolated in `TildeQuickLook`. Dependencies should remain pinned in `Package.swift` and `Package.resolved`.

## Testing Guidelines

Use XCTest. Name test files after the unit under test, for example `LineIndexTests.swift`, and use descriptive methods such as `testInsertionUpdatesFollowingLines()`. Add or update tests for behavior changes, especially in document loading, editor state, Markdown rendering, Quick Look HTML, encoding, and line endings. Run `swift test` before handing off changes; use `scripts/verify-host.sh Debug` for app or extension packaging work.

## Commit & Pull Request Guidelines

Recent history uses concise conventional-style subjects such as `fix: mark Quick Look preview as data based` and `chore: initialize repository and document workflow`. Keep commits focused. Pull requests should describe user-visible behavior, tests run, linked issues when applicable, and any macOS or Xcode validation that could not be performed. Include screenshots or recordings for visible UI changes.

## Security & Configuration Tips

Do not commit generated output such as `.build/`, DerivedData, local DMGs, or `tmp/`. Keep sandbox entitlements and signing changes in `Host/` deliberate and documented.
