# Changelog

All notable changes to Tilde are documented here. Work not yet included in a
tagged release is grouped under `Unreleased`.

## Unreleased

## 0.5.1 - 2026-08-23

- Prevent Finder and Launch Services opens from leaving an extra focused
  untitled document behind during app startup.
- Render Quick Look task-list checkboxes when a list item begins with a
  non-paragraph block, and preserve checkbox behavior across empty and
  multiple-paragraph items.
- Render supported inline and display math as MathML while keeping code and
  currency dollar signs literal, with safer handling for incomplete formulas.
- Correct Mermaid diagram orientation and share high-resolution image
  transformation logic between the app preview and Quick Look.
- Add regression coverage for Markdown rendering, math boundaries, task
  markers, and cross-node parsing behavior.

## 0.5.0 - 2026-08-21

- Preserve document restore sessions with app-scoped security bookmarks,
  including files on temporarily unavailable external volumes.
- Release document security-scoped access when documents close or change URL,
  with termination cleanup as a final safeguard.
- Keep command-line file opens, line navigation, and separate-window metadata
  associated with their corresponding file URLs.
- Bound and clean restore-session entries, retry legacy bookmarks, and add
  regression coverage for session persistence edge cases.

## 0.4.0 - 2026-08-20

- Add opt-in GFM-style task list checkboxes to the in-app Markdown preview.
- Add LaTeX-style inline and block math rendering to the in-app preview.
- Add Mermaid diagram rendering to the app preview and Finder Quick Look, with
  source, count, pixel, attachment, and output budgets.
- Keep Mermaid failures as safe code-block or failure fallbacks instead of
  failing the complete Markdown preview.
- Preserve preview layout across editor/preview mode changes and avoid
  modifying task markers inside indented code blocks or blockquotes.
- Add cache, budget, policy, blockquote, nested-list, and rendering regression
  coverage for the new Markdown features.

## 0.3.0 - 2026-08-12

- Add copy controls and language labels to fenced Markdown code blocks.
- Reduce Markdown preview memory use by releasing hidden preview state and
  downsampling oversized local and remote images.
- Prevent stale asynchronous preview renders from replacing newer content or
  error state.
- Bound undo history when editing large files and update the limit as documents
  cross the large-file threshold.

## 0.2.1 - 2026-08-09

- Fix the packaged command-line helper overwriting the main app executable on
  case-insensitive macOS filesystems.
- Add release checks that launch the packaged app's resource probe and verify
  the app and CLI helper are distinct executables.

## 0.2.0 - 2026-08-09

- Add fuzzy-ranked Quick Open results with a localized empty state.
- Add editor navigation history with Back and Forward commands, bounded history,
  and safe restoration after document changes.
- Add localized Markdown slash commands for headings, lists, tasks, quotes, and
  code blocks.
- Improve Markdown preview recovery with retry actions, image failure
  placeholders, and basic editor-to-preview scroll synchronization.
- Bundle the `tilde` command-line opener inside the macOS app and Homebrew cask.
- Preserve app entitlements and hardened-runtime signing metadata when rebuilding
  the host bundle.

## 0.1.4 - 2026-08-09

- Add opt-in remote Markdown image loading with sandbox network entitlement and
  attachment safety limits.

## 0.1.1 - 2026-08-08

- Add per-document editor state restoration for selection, scroll position, and
  Markdown view mode.
- Add Markdown split preview and automatic list continuation while editing.
- Preserve ordered-list formatting and improve empty-list exit behavior.
- Document the Apple Silicon-only release architecture.
- Reduce session persistence writes and migrate legacy path-based session keys.

## 0.1.0 - 2026-08-07

- Initial repository snapshot for the native macOS editor.
- SwiftPM-first package with document editing, Markdown preview, and Finder
  Quick Look support.
- Automated SwiftPM tests and macOS host verification workflow.
- Architecture decisions, keyboard shortcuts, performance baseline, dependency
  audit, and release checklist captured under `docs/`.
