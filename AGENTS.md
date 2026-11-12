# AGENTS.md — brain dev notes

## Commands

- `flutter pub get` / `flutter analyze` / `flutter test` — all must stay clean.
- `flutter run -d <device>` — Android emulator `Local_AVD` works locally.
- Unit tests: `test/brain_test.dart` (parsing, naming, search, themes — no
  widget tests; the app needs a real device/emulator to exercise UI).

## material_ui vs legacy material (important)

Flutter 3.50 split Material out to `package:material_ui`.
`package:flutter/material.dart` still exists but is deprecated and defines
**different `Material`/`TextField`/`Theme` classes**. Any widget package that
imports `package:flutter/material.dart` (e.g. `code_text_field`, media_kit's
stock video controls) will throw "No Material widget found" inside this app.

- All app code imports `package:material_ui/material_ui.dart`.
- Editor is a material_ui `TextField` + `_MarkdownEditingController`
  (buildTextSpan highlighting) — do not reintroduce code_text_field.
- Video uses `controls: NoVideoControls` + a tap overlay for the same reason.
- `flutter_markdown_plus` imports legacy material but only needs `Theme.of`
  (falls back silently) — tolerable; replace if it ever asserts.

## Vault conventions (matches the user's Obsidian work-log vault)

- Files: `yyyymmdd_Title_Case_Words.md` inside `yyyymmdd/` day folders.
- Daily log template includes `previous`/`next` frontmatter links.
- Brain writes standard `[text](path)` links only; `[[wikilink]]` /
  `![[embed]]` are parse-only for reading existing Obsidian vaults.

## Platform notes

- **macOS sandbox is disabled** (Runner entitlements) so a user-picked vault
  stays readable across restarts without security-scoped bookmarks.
- **No Xcode on the dev Mac** (no Apple ID) — iOS/macOS builds verified via
  CI `macos-latest` job instead. `xcodes install --latest` works if an Apple
  ID ever becomes available.
- **Linux CI test job** needs `libgtk-3-dev libx11-dev libxi-dev` —
  cnativeapi's native-assets hook (via desktop_drop) pkg-configs them during
  `flutter test`.
- `desktop_drop` applies KGP — Gradle prints a deprecation warning; harmless
  until Flutter requires built-in Kotlin.

## Agent skills

`.devin/skills/` vendors a curated subset of
[mattpocock/skills](https://github.com/mattpocock/skills) (MIT): `tdd`,
`diagnosing-bugs`, `code-review`, `research`, `wayfinder`, `prototype`,
`writing-for-agents` (model-invoked) plus `implement`, `implement-spec`,
`to-spec`, `to-tickets`, `triage`, `pr`, `handoff` (user-invoked only —
call them explicitly by name). Prefer `tdd` for fixes/features and
`diagnosing-bugs` for hard bugs; keep the vendored copies verbatim, fixes
go upstream or into project skills of our own.

## Versioning

Releases are **date-versioned**: assets are `brain_<yyyymmdd>.<ext>`
(`brain_20261112.apk`, `brain_20261112.dmg`, ...). A second same-day
release appends `_2`, `_3`, ... Cut releases via the `release` workflow
(Actions tab, or `git tag brain_<yyyymmdd> && git push --tags`). The
nightly-style `build` workflow keeps short artifact names on purpose.

## State/providers

Riverpod 3.x (`StateProvider` removed — plain providers in
`lib/core/providers.dart`). Editor exposes actions via `editorActionsProvider`
and `EditorActions` interface so tree/search/daily-note code can insert text
and save without widget refs.
