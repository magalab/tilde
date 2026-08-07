# ADR 0001: SPM-first project structure

## Status

Accepted.

## Decision

All application logic, reusable UI, third-party dependencies, and tests are
owned by `Package.swift`.

SwiftPM products are split into `TildeCore`, `TildeDocument`, `TildeEditor`,
`TildeMarkdown`, `TildeQuickLook`, and `TildeApplication`. The `Tilde`
executable is a one-line local development harness over `TildeApplication`.

SwiftPM cannot declare a macOS application bundle or Quick Look app-extension
product. A later Xcode host project may package these SPM products, but it must
contain only bundle configuration, entitlements, signing settings, and minimal
entry-point shims. It must not become a second dependency or source-management
system.

## Consequences

- `swift build` and `swift test` are the primary development gates.
- Package dependency revisions are pinned in `Package.swift` and
  `Package.resolved`.
- AppKit types remain isolated from `TildeCore`.
- Extension-safe code lives in `TildeCore` or `TildeQuickLook`.
