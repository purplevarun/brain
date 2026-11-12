# brain

A local-first, dark-only work-log app. Flutter single codebase for macOS,
Windows, Android and iOS. Inspired by Obsidian-style vaults but its own
thing: chronological daily logs + meeting/KT notes in plain Markdown.

## Features

- **Vaults are plain folders** — pick any directory; notes stay `.md` files
  you own. Attachments live next to the note that uses them.
- **`yyyymmdd` day folders** — daily logs (`yyyymmdd_Work_Log.md`) with
  `previous`/`next` frontmatter links, meetings and KT notes alongside.
- **Raw-Markdown editor** with inline syntax highlighting, autosave, and a
  live preview toggle.
- **Preview**: frontmatter card, `> [!type]` callouts, tappable checkboxes,
  image/video embeds (media_kit), tables, code blocks.
- **Standard `[text](path)` Markdown links.** For compatibility with existing
  Obsidian vaults, `[[wikilinks|alias]]` and `![[embeds]]` are *read* and
  rendered — brain never writes them.
- **Search** across all notes (line hits), **quick-open** palette
  (Ctrl/Cmd+K), **tag index** (frontmatter + `#inline` tags).
- **6 dark themes**: GitHub Dark (default), Tokyo Night, Dracula, Gruvbox,
  Catppuccin Mocha, Nord.
- **Backup**: export/import the whole vault as a `.zip`.

## Shortcuts

| Keys | Action |
|---|---|
| Ctrl/Cmd+K | Quick open |
| Ctrl/Cmd+N | New note |
| Ctrl/Cmd+Shift+N | Daily log |
| Ctrl/Cmd+E | Edit / preview |
| Ctrl/Cmd+S | Save |
| Ctrl/Cmd+B | Sidebar |

## Develop

```sh
flutter pub get
flutter analyze
flutter test
flutter run          # pick a device
```

See `AGENTS.md` for toolchain notes (material_ui, CI matrix, Xcode).

## CI

`.github/workflows/build.yml` builds Android APK, macOS `.app`, iOS
(`--no-codesign`) and Windows on every push, plus `analyze` + `test`.
Artifacts are attached to each run.
