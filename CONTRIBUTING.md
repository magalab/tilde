# Contributing to Tilde

Tilde is a macOS 15+ Swift 6 application. The repository uses Swift Package
Manager for the implementation and dependency graph, with a thin Xcode host
only for producing the `.app` and Quick Look `.appex` bundles.

## Prerequisites

- macOS 15 or newer
- Xcode with the macOS 15 SDK and its command-line tools
- Swift 6 (the toolchain shipped with the selected Xcode version)

Check the active toolchain before starting work:

```sh
swift --version
xcodebuild -version
```

## Build and test

From the repository root:

```sh
swift package resolve
swift build
swift test
```

Run the SwiftPM development executable with `swift run Tilde`. To build and
verify the native app bundle and embedded Quick Look extension, run:

```sh
scripts/verify-host.sh Debug
```

This command runs the package tests, builds the host project, checks the bundle
layout and localizations, verifies signing, and validates sandbox entitlements.
Use `scripts/run-benchmarks.sh` when a change affects document loading, editing,
Markdown rendering, or memory usage.

## Repository layout

| Path | Responsibility |
|---|---|
| `Package.swift` | SwiftPM products, targets, and pinned dependencies |
| `Sources/TildeCore` | Foundation-level policy, encoding, line endings, and localization |
| `Sources/TildeDocument` | `NSDocument` model, snapshots, and external-change handling |
| `Sources/TildeEditor` | TextKit 1 editor, settings, line numbers, and syntax highlighting |
| `Sources/TildeMarkdown` | In-app Markdown preview and attachment loading |
| `Sources/TildeQuickLook` | Sandboxed, extension-safe Markdown Quick Look renderer |
| `Sources/TildeApplication` | App commands, windows, and SwiftUI composition |
| `Host` | Bundle metadata, entitlements, and Xcode packaging shims |
| `Tests` | Target-level unit and integration tests |
| `docs` | Architecture decisions, baselines, shortcuts, and release evidence |

See [the architecture guide](docs/architecture.md) before changing module
boundaries or the host project.

## Change workflow

1. Create a focused branch from the current default branch.
2. Keep application logic in the appropriate SwiftPM target. Do not add a
   second dependency graph or move feature code into `Host/`.
3. Add or update tests with behavior changes, and update the relevant document
   when a workflow, shortcut, performance limit, or release requirement changes.
4. Run the smallest relevant check while iterating, then run `swift test` and
   `scripts/verify-host.sh Debug` before opening a pull request.
5. Keep generated output such as `.build/`, `DerivedData/`, local DMGs, and
   `tmp/` out of commits. The repository `.gitignore` covers these paths.

Pull requests should explain the user-visible behavior, test coverage, and any
macOS/Xcode-specific validation that could not run in CI. Keep commits small and
use imperative subjects, for example `Preserve selection after external reload`.

## Distribution notes

The Tilde project license is intentionally still pending. Do not publish source
or binaries until a project `LICENSE` is selected and the exact third-party
license texts and notices described in
[`docs/dependency-licenses.md`](docs/dependency-licenses.md) are bundled.
