import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/brain_markdown.dart';
import '../../core/frontmatter.dart';
import '../../core/models.dart';
import '../../core/platform_utils.dart';
import '../../core/providers.dart';
import '../../core/vault_store.dart';
import 'video_embed.dart';

/// Everything preview builders need: vault access, theme, callbacks.
/// Media/link/checkbox handlers live here so nested content (callouts)
/// renders identically to top-level content.
class PreviewEnv {
  const PreviewEnv({
    required this.theme,
    required this.store,
    required this.noteRelPath,
    required this.allFiles,
    required this.onOpenNote,
    required this.onMissingFile,
    required this.onToggleCheckbox,
    required this.styleSheet,
    required this.nextCheckboxIndex,
  });

  final BrainTheme theme;
  final VaultStore store;
  final String noteRelPath;
  final List<String> allFiles;
  final void Function(String relPath) onOpenNote;
  final void Function(String message) onMissingFile;
  final void Function(int checkboxIndex) onToggleCheckbox;
  final MarkdownStyleSheet styleSheet;
  final int Function() nextCheckboxIndex;

  Map<String, MarkdownElementBuilder> get builders => {
    'callout': CalloutBuilder(this),
    'wikilink': WikilinkBuilder(this),
  };

  /// href (raw, already uri-decoded) -> vault relPath, null if it escapes.
  String? resolveHref(String href) => store.resolveRel(noteRelPath, href);

  Widget mediaBuilder(Uri uri, String? title, String? alt) {
    final decoded = Uri.decodeComponent(uri.path);
    final rel = resolveHref(decoded) ?? decoded;
    final abs = store.absolute(rel);
    if (isVideoPath(decoded)) {
      return VideoEmbed(path: abs, title: alt ?? title);
    }
    final file = File(abs);
    if (!file.existsSync()) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(8),
          color: theme.surfaceAlt,
        ),
        child: Row(
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 16,
              color: theme.textDim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alt?.isNotEmpty == true ? alt! : decoded,
                style: TextStyle(color: theme.textDim, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, fit: BoxFit.contain),
      ),
    );
  }

  Widget checkboxBuilder(bool value) {
    final i = nextCheckboxIndex();
    return GestureDetector(
      onTap: () => onToggleCheckbox(i),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          value ? Icons.check_box : Icons.check_box_outline_blank,
          size: 16,
          color: value ? theme.accent : theme.textDim,
        ),
      ),
    );
  }

  void tapLink(String? href) {
    if (href == null) return;
    if (href.startsWith('http://') || href.startsWith('https://')) {
      openUrl(href);
      return;
    }
    final decoded = Uri.decodeComponent(href);
    final rel = resolveHref(decoded);
    if (rel == null) {
      onMissingFile('Link escapes the vault: $decoded');
      return;
    }
    if (rel.toLowerCase().endsWith('.md')) {
      onOpenNote(rel);
      return;
    }
    final abs = store.absolute(rel);
    if (File(abs).existsSync()) {
      openFileExternally(abs);
    } else {
      onMissingFile('Not found: $rel');
    }
  }

  void tapWikilink(String target) {
    final resolved = resolveWikilink(target, allFiles, noteRelPath);
    if (resolved != null) {
      onOpenNote(resolved);
    } else {
      onMissingFile('No note named "$target"');
    }
  }
}

/// Rendered note: frontmatter card + markdown body with callouts, media
/// embeds, wikilink read-support and tappable checkboxes.
class NotePreview extends ConsumerStatefulWidget {
  const NotePreview({
    super.key,
    required this.relPath,
    required this.raw,
    required this.onToggleCheckbox,
  });

  final String relPath;
  final String raw;
  final void Function(int checkboxIndex) onToggleCheckbox;

  @override
  ConsumerState<NotePreview> createState() => _NotePreviewState();
}

class _NotePreviewState extends ConsumerState<NotePreview> {
  int _checkboxCounter = 0;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(brainThemeProvider);
    final store = ref.read(vaultStoreProvider)!;
    final allFiles = ref.watch(allFilesProvider).value ?? const [];
    final note = parseNote(widget.raw);

    final env = PreviewEnv(
      theme: theme,
      store: store,
      noteRelPath: widget.relPath,
      allFiles: allFiles,
      onOpenNote: (rel) {
        if (File(store.absolute(rel)).existsSync()) {
          ref.read(openPathProvider.notifier).state = rel;
        } else {
          _missing('Not found: $rel');
        }
      },
      onMissingFile: _missing,
      onToggleCheckbox: widget.onToggleCheckbox,
      styleSheet: markdownStyleSheet(theme),
      nextCheckboxIndex: () => _checkboxCounter++,
    );

    _checkboxCounter = 0;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note.hasFrontmatter && !note.meta.isEmpty)
              _FrontmatterCard(meta: note.meta, theme: theme),
            MarkdownBody(
              data: preprocessEmbeds(note.body),
              extensionSet: brainExtensionSet(),
              builders: env.builders,
              styleSheet: env.styleSheet,
              imageBuilder: env.mediaBuilder,
              checkboxBuilder: env.checkboxBuilder,
              onTapLink: (text, href, title) => env.tapLink(href),
            ),
          ],
        ),
      ),
    );
  }

  void _missing(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/// YAML frontmatter rendered as a properties card above the note body.
class _FrontmatterCard extends StatelessWidget {
  const _FrontmatterCard({required this.meta, required this.theme});

  final NoteMeta meta;
  final BrainTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          for (final e in meta.fields.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      e.key,
                      style: TextStyle(color: theme.textDim, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _fmt(e.value),
                      style: TextStyle(color: theme.text, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(dynamic v) =>
      v is List ? v.map(_fmt).join(', ') : v?.toString() ?? '';
}

/// Renders `<callout type source>` elements as Obsidian-style panels.
class CalloutBuilder extends MarkdownElementBuilder {
  CalloutBuilder(this.env);

  final PreviewEnv env;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final type = element.attributes['type'] ?? 'note';
    final title = element.attributes['title'] ?? '';
    final source = element.attributes['source'] ?? '';
    final color = env.theme.calloutColor(type);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_calloutIcon(type), size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.isNotEmpty
                      ? title
                      : type[0].toUpperCase() + type.substring(1),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MarkdownBody(
            data: source,
            extensionSet: brainExtensionSet(),
            builders: env.builders,
            styleSheet: env.styleSheet,
            imageBuilder: env.mediaBuilder,
            checkboxBuilder: env.checkboxBuilder,
            onTapLink: (text, href, title) => env.tapLink(href),
          ),
        ],
      ),
    );
  }

  static IconData _calloutIcon(String type) => switch (type) {
    'tip' || 'hint' || 'success' || 'check' || 'done' =>
      Icons.lightbulb_outline,
    'warning' || 'caution' || 'attention' => Icons.warning_amber_rounded,
    'danger' || 'error' || 'fail' || 'failure' || 'bug' => Icons.error_outline,
    'important' => Icons.priority_high,
    'question' || 'help' || 'faq' => Icons.help_outline,
    'quote' || 'cite' => Icons.format_quote,
    _ => Icons.info_outline,
  };
}

/// Renders `[[name]]` / `[[name|alias]]` as a note link (read-support).
class WikilinkBuilder extends MarkdownElementBuilder {
  WikilinkBuilder(this.env);

  final PreviewEnv env;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final target = element.attributes['target'] ?? element.textContent;
    return Text.rich(
      TextSpan(
        text: element.textContent,
        style: (preferredStyle ?? const TextStyle()).copyWith(
          color: env.theme.accent,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => env.tapWikilink(target),
      ),
    );
  }
}

/// Finds the vault file a `[[target]]` points to: exact relPath, then
/// basename match (preferring .md and files in the note's own folder).
String? resolveWikilink(
  String target,
  List<String> files,
  String noteRelPath,
) {
  final t = Uri.decodeComponent(target).replaceAll(r'\', '/');
  if (files.contains(t)) return t;
  final tBase = t.split('/').last;
  final noteDir = noteRelPath.contains('/')
      ? noteRelPath.substring(0, noteRelPath.lastIndexOf('/'))
      : '';
  final matches = files.where((f) {
    final base = f.split('/').last;
    return base == tBase ||
        (base.toLowerCase().endsWith('.md') &&
            base.substring(0, base.length - 3) == tBase);
  }).toList();
  if (matches.isEmpty) return null;
  matches.sort((a, b) {
    final aSame = a.startsWith('$noteDir/') ? 0 : 1;
    final bSame = b.startsWith('$noteDir/') ? 0 : 1;
    if (aSame != bSame) return aSame - bSame;
    final aMd = a.endsWith('.md') ? 0 : 1;
    final bMd = b.endsWith('.md') ? 0 : 1;
    return aMd - bMd;
  });
  return matches.first;
}

MarkdownStyleSheet markdownStyleSheet(BrainTheme t) {
  final base = TextStyle(color: t.text, fontSize: 14, height: 1.55);
  return MarkdownStyleSheet(
    a: TextStyle(color: t.accent),
    p: base,
    h1: base.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
    h2: base.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
    h3: base.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600),
    h4: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    h5: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    h6: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    em: base.copyWith(fontStyle: FontStyle.italic),
    strong: base.copyWith(fontWeight: FontWeight.w700),
    del: base.copyWith(
      decoration: TextDecoration.lineThrough,
      color: t.textDim,
    ),
    code: base.copyWith(
      fontFamily: 'monospace',
      fontSize: 12.5,
      backgroundColor: t.codeBg,
      color: t.orange,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: t.codeBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: t.border),
    ),
    blockquote: base.copyWith(color: t.textDim),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: t.border, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    listBullet: base.copyWith(color: t.accent),
    tableHead: base.copyWith(fontWeight: FontWeight.w600),
    tableBody: base,
    tableBorder: TableBorder.all(color: t.border),
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: t.border)),
    ),
    blockSpacing: 10,
    listIndent: 20,
  );
}
