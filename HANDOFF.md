# HANDOFF.md — brain project context

Read this first when picking up the project. `AGENTS.md` (conventions) and
`README.md` (user docs) complement it.

## What brain is

A private, local-first, dark-mode work-log app — "stripped-down Obsidian" with
its own personality. Single Flutter codebase (`package:material_ui`, not
legacy `package:flutter/material.dart`) for macOS, Windows, Android, iOS.
Repo: `github.com/purplevarun/brain` (private).

A **vault** is a plain folder of markdown + attachments — the user's real
vault is `obsidian_falabella_work_logs` (`yyyymmdd/` day folders,
`yyyymmdd_Title_Case_Words.md`, wikilinks, `![[embeds]]`, callouts, daily
logs). brain reads that layout; it only *writes* standard markdown links.

## Priorities (user's words, this order)

1. **Finish the macOS app first.** Don't spend effort on other platforms
   until the mac workflow is proven.
2. Proper **e2e tests** for the real flows (see `test/e2e_vault_flows_test.dart`).
3. Backup files are **`.purplebrain`** (a zip archive of the vault — not a
   database; rename to `.zip` to inspect).
4. README is **user-facing only** — how to use the app + shortcuts, no dev
   content.
5. Releases are **date-versioned**: `brain_<yyyymmdd>.<ext>` via the
   `release` workflow.
6. Matt Pocock workflow skills are vendored in `.devin/skills/` — use them
   (tdd, diagnosing-bugs, code-review, …).

## Current state (2026-11-12)

- macOS dead-buttons bug **diagnosed and fixed**: `file_picker` 2.5.x gates
  every dialog behind `com.apple.security.files.user-selected.*` entitlements;
  the entitlements files only had `app-sandbox=false`. Added
  `files.user-selected.read-write` to DebugProfile + Release entitlements.
  Vault-picker/backup handlers now also surface errors as snackbars instead
  of dying silently.
- `.purplebrain` implemented: `exportVaultBackup`/`importVaultBackup` in
  `lib/features/vault/backup.dart` (pure `buildVaultArchive` /
  `extractVaultArchive` seams for tests). Import also accepts legacy `.zip`.
- Two real layout bugs found by the new tests and fixed: sidebar tab row
  overflow at ~800px wide; settings sheet not scrollable in short windows.
- Feature batch (user request): shortcuts reworked (Cmd+P/K quick open,
  Cmd+N note, Cmd+Shift+N folder, Cmd+Shift+D daily, Cmd+0/1 focus
  sidebar/editor, Cmd+, settings; Cmd+S removed — autosave-only).
  Per-vault `.purplebrain/config.json` (`autosave_ms`, slider in Settings,
  100–2000ms). Sidebar split into "Daily logs" (`yyyymmdd` dirs) + "Notes".
  New-vault flow asks for a name. New crystal/neural app icon (generated
  `brain_icon_1024` via Swift, all platform sizes) + `BrainMark` painter
  replaces `Icons.psychology`. macOS menu bar strips Edit/View/Window/Help
  in AppDelegate.
- Next step when this lands: user installs the new `brain_<date>.dmg` and
  verifies the three vault buttons + export/import on the real app.
- Second batch (user request): global `HardwareKeyboard` shortcuts (fire
  even with a TextField focused) + Cmd+E two-segment Edit/Preview pill;
  text zoom Cmd+= / Cmd+- / Cmd+Shift+0 (textScaler on editor+preview,
  persisted in config `zoom`); Tab/Shift+Tab line indent in editor
  (`lib/features/editor/indent.dart`, pure + unit-tested); sidebar is now
  VS Code-style stacked collapsible sections — Daily Notes + Notes
  expanded on top, Search + Tags collapsed headers below (tab row and
  `sidebarTabProvider` deleted; `FileTree` → `TreeNodes` +
  `splitDailyNotes`).
- **Release publishing broke mid-session**: `GITHUB_TOKEN` 403s on
  `gh release create` despite `Contents: write` (worked through _4, user's
  PAT works). _5/_6 were published manually from CI artifacts. Publish
  step now prefers `secrets.RELEASE_TOKEN` (a contents:write PAT) if the
  user adds it, and re-resolves a free tag at publish time (two concurrent
  runs computed the same `_N` suffix).

## Environment realities

- **No Xcode / no Apple ID** on the dev Mac → cannot build macOS/iOS
  locally. Every macOS fix ships via CI release → download dmg → install.
  Android emulator `Local_AVD` works locally.
- `flutter analyze` + `flutter test` must stay green (21 tests).
- The dev Mac is unsandboxed for the app (needed for a picked vault folder
  to persist across restarts).

## Test gotchas learned the hard way

- `DirectoryWatcher` on macOS is **polling** (Timer.periodic) → once a vault
  is open `pumpAndSettle` never returns. Use `tester.runAsync` + bounded
  `pump`s in widget tests.
- The `testWidgets` body runs in **fake-async** — real file IO awaited
  directly in the test body hangs forever. Wrap in `tester.runAsync`.
- `FilePickerPlatform.instance = FakeFilePicker()` is the seam for faking
  OS dialogs; `saveFile`'s `allowedExtensions` param is a deprecated no-op —
  the extension comes from `fileName`.

## Deliberate decisions

- **Wikilinks kept (parse-only)**: the user's real vault is 100% wikilinks;
  stripping would break reading it. brain writes `[text](path)` only.
- **Backup = zip-in-`.purplebrain`**, not SQLite: the vault is already files
  on disk; a zip container preserves layout, works with any archive tool,
  and stays future-proof for sync. No DB layer exists anywhere in the app.
- `window_manager` uses the 0.5.x legacy bridge — the 0.7 API needs
  experimental multi-window controllers (disproportionate for v1).
- macOS sandbox stays **off** (security-scoped bookmarks are fragile
  without an Apple ID/dev account anyway).

## Open threads

- Verify the new dmg on the real Mac (buttons, export, import).
- Watch whether the `GITHUB_TOKEN` release-create 403 heals; if not, add a
  `RELEASE_TOKEN` (contents:write) repo secret — the publish step already
  prefers it.
- iOS build is CI-verified only (`--no-codesign`); real device install still
  needs an Apple ID/Xcode.
- Windows build is CI-verified; no local Windows machine to try it.
- Sync (cloud/git) is "maybe later" — export is the backup story for now.
