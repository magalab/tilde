# Tilde

Tilde is a lightweight native macOS plain-text editor with Markdown preview and
a Finder Quick Look extension. The editor is built around `NSDocument`, a
document-owned `NSTextStorage`, and `NSTextView`; SwiftUI provides the surrounding
window UI and settings.

The project requires macOS 15+, Swift 6, and Xcode with the macOS 15 SDK.

## Repository guide

- [Contributing and development workflow](CONTRIBUTING.md)
- [Architecture and module boundaries](docs/architecture.md)
- [Keyboard shortcuts](docs/keyboard-shortcuts.md)
- [Release checklist](docs/release-checklist.md)
- [Architecture decisions](docs/adr/)
- [Performance baseline](docs/performance-baseline.md)
- [Dependency license audit](docs/dependency-licenses.md)

The package manifest is the source of truth for application code, dependencies,
and tests. The Xcode project in `Host/` only packages those products into the
macOS app and Quick Look extension; see [the architecture guide](docs/architecture.md)
for the boundary in more detail.

## Development with SwiftPM

Swift Package Manager owns all application logic, reusable UI, dependencies,
tests, and the benchmark tool:

```sh
swift build
swift test
swift run Tilde
```

Dependencies are pinned to exact revisions in `Package.swift` and
`Package.resolved`. `TildeBenchmark` is also an SPM executable product:

```sh
scripts/run-benchmarks.sh
```

## Native app and Quick Look bundles

SwiftPM cannot declare Apple `.app` and `.appex` bundle product types. The thin
project in `Host/` only packages the local `TildeApplication` and
`TildeQuickLook` SPM products; it is not a second source or dependency graph.

```sh
scripts/build-host.sh Debug
scripts/verify-host.sh Debug
```

The verified app is written to
`.build/HostDerivedData/Build/Products/Debug/Tilde.app`. Local builds are ad-hoc
signed. Distribution builds require the project's Developer ID identity and
notarization credentials.

To create a local DMG from a verified build:

```sh
scripts/build-dmg.sh Release
```

The generated DMG is intentionally ignored by Git. Release signing,
notarization, and clean-machine validation are tracked in the release checklist.

To install the latest release with Homebrew:

```sh
brew tap magalab/homebrew-tap
brew install --cask tilde
```

## Design and release evidence

- [SPM-first ADR](docs/adr/0001-spm-first.md)
- [Native host and Quick Look ADR](docs/adr/0002-native-host-and-quick-look.md)
- [Performance baseline](docs/performance-baseline.md)
- [Keyboard shortcuts](docs/keyboard-shortcuts.md)
- [Dependency license audit](docs/dependency-licenses.md)
- [Release checklist](docs/release-checklist.md)

The project is licensed under the [MIT License](LICENSE). Third-party
dependencies remain subject to their own licenses; see
[the dependency license audit](docs/dependency-licenses.md).
