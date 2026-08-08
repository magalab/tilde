# Changelog

All notable changes to Tilde will be documented here. Until the first public
release, changes are grouped under `Unreleased`.

## 0.1.1 - 2026-08-08

- Add per-document editor state restoration for selection, scroll position, and
  Markdown view mode.
- Add Markdown split preview and automatic list continuation while editing.
- Preserve ordered-list formatting and improve empty-list exit behavior.
- Document the Apple Silicon-only release architecture.
- Reduce session persistence writes and migrate legacy path-based session keys.

## Unreleased

- Initial repository snapshot for the native macOS editor.
- SwiftPM-first package with document editing, Markdown preview, and Finder
  Quick Look support.
- Automated SwiftPM tests and macOS host verification workflow.
- Architecture decisions, keyboard shortcuts, performance baseline, dependency
  audit, and release checklist captured under `docs/`.
