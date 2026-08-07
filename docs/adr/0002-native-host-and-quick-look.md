# ADR 0002: Native host, text system, and Quick Look boundary

## Status

Accepted.

## Context

SwiftPM owns Tilde's implementation and dependency graph, but SwiftPM cannot
describe a signed macOS `.app` with an embedded Quick Look `.appex`. The editor
also needs one authoritative text buffer, while the Quick Look extension must
render untrusted Markdown without inheriting application-only behavior.

## Decisions

### Thin Xcode packaging host

`Host/TildeHost.xcodeproj` contains only bundle metadata, entitlements, build
settings, an app entry-point shim, and an extension entry-point shim. It uses
local SwiftPM products `TildeApplication` and `TildeQuickLook`; it does not own
application features or third-party packages.

`swift build` and `swift test` remain the primary development commands.
`scripts/build-host.sh` adds the packaging pass, and `scripts/verify-host.sh`
checks both the package and the resulting native bundles.

### TextKit 1 for v1

The v1 editor uses a document-owned `NSTextStorage` connected directly to an
`NSTextView` through TextKit 1. This preserves a single authoritative buffer,
Undo and document change tracking, selection, and IME behavior without a
SwiftUI `String` mirror. TextKit 2 can be reconsidered only if it can preserve
those invariants with a measurable benefit.

The line index stores relative line lengths in blocks of at most 512 lines.
An ordinary edit rebuilds its affected block instead of shifting every later
line offset. Cursor-to-column conversion reads the document's `NSString`
storage directly and only materializes the current line prefix.

### Quick Look isolation

The extension declares only `net.daringfireball.markdown`. Its SwiftPM
renderer uses `swift-markdown`, escapes raw HTML, rejects dangerous or remote
URLs, permits local images only through bounded in-directory attachments, and
applies source/output/resource budgets. It does not link the app's Textual
renderer or UI modules.

The app sandbox permits user-selected read/write access. The extension has its
own sandbox entitlement and obtains file access from the Quick Look request.
Release builds retain the hardened runtime; local smoke builds use ad-hoc
signing.

## Validation

The repeatable local gate is:

```sh
scripts/verify-host.sh Debug
```

In addition to the automated gate, the built Debug app was launched and macOS
registered `dev.tilde.editor.quicklook`. A Finder-equivalent `qlmanage -p -x`
request for `Tests/Fixtures/quicklook.md` launched the embedded extension
process. Distribution signing, notarization, and a clean-machine installation
remain release-environment checks because they require project credentials.

## Consequences

- There is one source/dependency graph: `Package.swift`.
- Xcode is required only to produce and sign Apple bundle product types.
- App preview and Quick Look deliberately use separate renderers and security
  budgets.
- TextKit 1 is an explicit v1 choice, not an accidental fallback.
