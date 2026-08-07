# Architecture guide

## System boundary

Tilde has one implementation and dependency graph: `Package.swift`. The
`Host/TildeHost.xcodeproj` project is a packaging layer required by Apple bundle
product types; it contains metadata, entitlements, signing settings, and small
entry-point shims only.

```text
                         +-------------------------+
                         | Host/TildeHost.xcodeproj |
                         | app + Quick Look bundles |
                         +------------+------------+
                                      |
                 local SwiftPM products and bundle configuration
                                      |
       +------------------------------+------------------------------+
       |                                                             |
  TildeApplication                                           TildeQuickLook
       |                                                             |
  TildeMarkdown                                                  TildeCore
       |                                                             |
  TildeEditor                                                   (no UI)
       |
  TildeDocument
       |
   TildeCore
```

`TildeApp` is a small SwiftPM executable for local development. `TildeBenchmark`
exercises the same core, document, Markdown, and Quick Look modules without
launching the native host.

## Module responsibilities

| Module | Owns | Must not own |
|---|---|---|
| `TildeCore` | Encoding, line endings, line indexing, file-size/Markdown policy, localization, and shared value types | AppKit document or window state |
| `TildeDocument` | `NSDocument`, document snapshots, metadata, save/load, and external-change state | Markdown rendering or editor view layout |
| `TildeEditor` | TextKit 1 storage/view wiring, editing settings, line numbers, and syntax highlighting | Window commands or Quick Look code |
| `TildeMarkdown` | In-app preview, Textual integration, and bounded local attachment loading | Extension-only APIs and app lifecycle |
| `TildeQuickLook` | Sandboxed Markdown parsing and HTML rendering for Quick Look | `TildeEditor`, `TildeMarkdown`, or app-only UI |
| `TildeApplication` | Menus, commands, windows, and SwiftUI composition | Package/dependency configuration |

Keep lower-level modules independent of higher-level UI modules. When a value or
policy is needed by both the app and extension, place it in `TildeCore` only if
it can remain Foundation-only and extension-safe.

## Editor data flow

`TildeDocument` owns the authoritative `NSTextStorage`. `TildeEditor` connects
that storage to an `NSTextView` and keeps selection, undo, IME, and document
change tracking in the AppKit text system. SwiftUI views observe presentation
state and settings; they do not maintain a second full-file `String` mirror.

The line index stores relative line lengths in bounded blocks. Ordinary edits
rebuild only the affected block, while cursor-to-column conversion reads the
current line from the document storage.

## Markdown and Quick Look boundaries

The in-app preview and the Quick Look extension deliberately use separate
renderers. Quick Look parses untrusted input under explicit source, output, and
attachment budgets. Raw HTML is escaped, remote or dangerous URLs are rejected,
and local images are resolved only from bounded in-directory attachments.

Markdown preview is disabled above the 5 MiB source ceiling. Large File Mode
starts at 50 MiB, and 100 MiB is the largest validated v1 document size. These
limits are documented and measured in
[`docs/performance-baseline.md`](performance-baseline.md).

## Validation map

- `swift test` covers core policies, document behavior, editor behavior,
  Markdown preview, and Quick Look rendering.
- `scripts/verify-host.sh Debug` adds host packaging, localization, signing,
  entitlements, and extension registration checks.
- `scripts/run-benchmarks.sh` records the document and Markdown performance
  matrix used for regression checks.

For design changes, record a durable decision in `docs/adr/` and link it from
the README when it changes a repository-wide boundary.
