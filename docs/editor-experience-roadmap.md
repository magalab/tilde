# Editor experience roadmap

This roadmap records the status of Tilde's lightweight editor and Markdown
workflow as of version 0.2.0. It intentionally keeps Tilde focused on fast,
native plain-text editing rather than expanding it into a full IDE.

## Completed in 0.2.0

- Quick Open supports fuzzy matching, filename-prioritized ranking, keyboard
  selection, and an empty-results state without hiding recent projects.
- Markdown preview provides retryable errors, localized image failure
  placeholders, and basic one-way scroll synchronization from source to preview.
- Editor navigation provides bounded Back and Forward history with
  Option-Command-Left and Option-Command-Right, including safe range clamping
  when document contents change.
- Markdown slash commands insert headings, bullet and numbered lists, task
  lists, quotes, and code blocks. They are localized, undoable, limited to the
  first non-whitespace position, and disabled inside fenced code blocks.

## Next priorities

### Quick Open locations

Accept inputs such as `README.md:42` and open the selected file at the requested
line by reusing the existing command-line request and Go to Line paths.

### Recent files

Show valid `NSDocumentController.recentDocumentURLs` separately from recent
project directories when Quick Open has an empty query.

### Navigation and Markdown refinements

- Ignore escaped delimiters, inline code, and string-like regions when matching
  brackets where practical without introducing a parser dependency.
- Add slash-command filtering and richer commands only after defining the
  required parameter-entry interaction.
- Replace approximate preview scroll synchronization only if the rendering
  layer exposes stable Markdown block identities.

## Deferred

General source-language highlighting, Tree-sitter integration, LSP features,
project indexing, Git UI, plugins, and block editing are separate projects. A
future source-highlighting effort should begin with extension-based language
selection, incremental TextKit coloring, large-file degradation, fixtures, and
performance baselines before considering a parser dependency.
