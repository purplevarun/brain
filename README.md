# brain

A local-first, dark-mode work log for your notes — like a stripped-down
Obsidian, but simpler. Your notes live as plain `.md` files in a folder you
own; nothing goes to any server.

## Getting started

1. Open brain. On the first screen, choose one of:
   - **Open a vault folder** — point it at an existing notes folder
     (an Obsidian vault works great).
   - **Create a new vault** — pick a parent folder; brain makes a
     `brain_vault/` folder inside it.
   - **Import vault backup (.purplebrain)** — restore from a backup file.
2. The left sidebar has three tabs: **Files**, **Search**, **Tags**.
   Click a note to open it.

## Daily notes

Hit the calendar icon (or `Ctrl/Cmd+Shift+N`) to create today's work log:
brain makes a `yyyymmdd/` folder containing
`yyyymmdd_Work_Log.md`, with frontmatter linking to the previous/next days.

## Writing notes

- Toggle **edit / preview** with the pencil icon or `Ctrl/Cmd+E`.
- The editor is raw Markdown with highlighting; it autosaves every few
  hundred milliseconds — tune the interval in Settings (it's saved
  per-vault in `.purplebrain/config.json`).
- Supported in preview: headings, `> [!info]`/`[!warning]`/`[!note]`
  callouts, checkboxes (clickable — ticking one rewrites the file), tables,
  code blocks, YAML frontmatter cards, images and videos.
- Links: use `[text](note.md)` — paths are relative to the note. Existing
  `[[wikilinks|aliases]]` and `![[embeds]]` from Obsidian vaults render
  fine too.
- Drag or attach files to embed them next to the note.

## Finding things

- **Search tab**: searches every note, shows matching lines; click a hit
  to jump to it.
- **Quick open** (`Ctrl/Cmd+K`): fuzzy-find any file by name.
- **Tags tab**: index of `#tags` from frontmatter and inline; click a tag
  to list its notes, click a note to open it.

## Themes

Settings gear → pick a theme. Six dark themes ship: GitHub Dark
(default), Tokyo Night, Dracula, Gruvbox, Catppuccin Mocha, Nord.
Your choice is remembered.

## Backups — `.purplebrain` files

Settings gear → **Export backup** saves your whole vault as one file:
`brain_vault_<date>_<time>.purplebrain`.

**What's inside a `.purplebrain`?** It's not a database — it's a standard
**zip archive** of the vault folder (all your `.md` notes and attachments,
hidden files skipped). Rename it to `.zip` and it opens in any archive
tool. **Import backup** (also on the first-run screen) unpacks it into a
folder you choose and opens it as your vault. `.zip` backups still work.

## Shortcuts

| Keys | Action |
|---|---|
| `Ctrl/Cmd+P` (or `K`) | Quick open — find files |
| `Ctrl/Cmd+N` | New note |
| `Ctrl/Cmd+Shift+N` | New folder |
| `Ctrl/Cmd+D` | Today's daily log |
| `Ctrl/Cmd+E` | Toggle edit / preview |
| `Ctrl/Cmd+0` | Focus the sidebar |
| `Ctrl/Cmd+1` | Focus the editor |
| `Ctrl/Cmd+B` | Collapse / expand the sidebar |
| `Ctrl/Cmd+=` / `Ctrl/Cmd+-` | Zoom text in / out |
| `Ctrl/Cmd+Shift+0` | Reset zoom |
| `Tab` / `Shift+Tab` | Indent / dedent lines in the editor |
| `Ctrl/Cmd+,` | Settings |

There's no save shortcut — notes autosave constantly.
On macOS the menu bar only shows the app and File menus; everything else
is keyboard-driven.

All data stays local on your device. Export a `.purplebrain` whenever you
want a copy elsewhere.
