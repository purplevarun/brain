import 'dart:io';

import 'package:brain/app/theme/brain_theme.dart';
import 'package:brain/core/brain_markdown.dart';
import 'package:brain/core/frontmatter.dart';
import 'package:brain/core/naming.dart';
import 'package:brain/core/vault_store.dart';
import 'package:brain/features/search/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  group('frontmatter', () {
    test('parses yaml frontmatter and body', () {
      const raw = '---\ntitle: Hi\ntags:\n  - a\n  - b\n---\n\n# Body\n';
      final note = parseNote(raw);
      expect(note.hasFrontmatter, isTrue);
      expect(note.meta.title, 'Hi');
      expect(note.meta.tags, ['a', 'b']);
      expect(note.body.trim(), '# Body');
    });

    test('no frontmatter returns body unchanged', () {
      final note = parseNote('# Just md\n');
      expect(note.hasFrontmatter, isFalse);
      expect(note.meta.isEmpty, isTrue);
      expect(note.body, '# Just md\n');
    });

    test('extractTags merges frontmatter + inline, skips code', () {
      final note = parseNote('---\ntags: [work-log]\n---\n#tag1 ```#notag```\n`#no` #TAG2\n');
      final tags = extractTags(note.meta, note.body);
      expect(tags, containsAll(['work-log', 'tag1', 'tag2']));
      expect(tags, isNot(contains('notag')));
    });
  });

  group('naming', () {
    final day = DateTime(2026, 11, 5);

    test('slugifyTitle', () {
      expect(slugifyTitle('Prisma ML mockups: meeting!'),
          'Prisma_ML_Mockups_Meeting');
      expect(slugifyTitle('  spaced   out  '), 'Spaced_Out');
    });

    test('noteFileName prefixes yyyymmdd', () {
      expect(noteFileName('My Note', day), '20261105_My_Note.md');
    });

    test('dailyLogRelPath uses day folder', () {
      expect(dailyLogRelPath(day), '20261105/20261105_Work_Log.md');
    });

    test('fillNextField sets and inserts next:', () {
      final withNext = fillNextField(
          '---\ntype: work-log\nnext:\n---\nbody', '20261106_Work_Log.md');
      expect(withNext, contains('next: "20261106_Work_Log.md"'));
      final noNext = fillNextField(
          '---\ntype: work-log\n---\nbody', '20261106_Work_Log.md');
      expect(noNext, contains('next: "20261106_Work_Log.md"\n---'));
    });
  });

  group('brain_markdown', () {
    test('callout parses to callout element with type and source', () {
      final doc = md.Document(extensionSet: brainExtensionSet());
      final nodes =
          doc.parse('> [!warning] Watch out\n> line two\n\nnormal\n');
      final callout = nodes.whereType<md.Element>().firstWhere(
            (e) => e.tag == 'callout',
          );
      expect(callout.attributes['type'], 'warning');
      expect(callout.attributes['title'], 'Watch out');
      expect(callout.attributes['source'], 'line two');
    });

    test('plain blockquote is not a callout', () {
      final doc = md.Document(extensionSet: brainExtensionSet());
      final nodes = doc.parse('> just a quote\n');
      expect(
        nodes.whereType<md.Element>().any((e) => e.tag == 'callout'),
        isFalse,
      );
    });

    test('wikilink parses target and alias', () {
      final doc = md.Document(extensionSet: brainExtensionSet());
      final nodes = doc.parse('see [[20261104_Note|the note]]\n');
      final link = nodes
          .whereType<md.Element>()
          .expand((e) => e.children ?? <md.Node>[])
          .whereType<md.Element>()
          .firstWhere((e) => e.tag == 'wikilink');
      expect(link.attributes['target'], '20261104_Note');
      expect(link.textContent, 'the note');
    });

    test('preprocessEmbeds rewrites standalone ![[x]] only', () {
      expect(preprocessEmbeds('![[a.mp4]]'), '![](a.mp4)');
      expect(preprocessEmbeds('inline ![[a.png]] stays'),
          'inline ![[a.png]] stays');
    });
  });

  group('vault + search', () {
    test('search finds lines across files', () async {
      final dir = await Directory.systemTemp.createTemp('brain_vault');
      await File('${dir.path}/a.md').writeAsString('hello world\nother\n');
      await File('${dir.path}/b.md').writeAsString('nothing\n');
      final store = VaultStore(dir.path);
      final hits = await searchNotes(store, 'hello');
      expect(hits, hasLength(1));
      expect(hits.first.path, 'a.md');
      expect(hits.first.line, 1);
      await dir.delete(recursive: true);
    });

    test('resolveRel keeps links inside vault', () {
      final store = VaultStore('/vault');
      expect(store.resolveRel('2026/n.md', 'x.png'), '2026/x.png');
      expect(store.resolveRel('2026/n.md', '../o.md'), 'o.md');
      expect(store.resolveRel('n.md', '../evil.md'), isNull);
    });
  });

  test('themes are all dark and github dark is default', () {
    expect(defaultThemeName, 'GitHub Dark');
    for (final t in brainThemes) {
      expect(t.bg.computeLuminance() < 0.5, isTrue, reason: t.name);
    }
  });
}
