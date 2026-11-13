import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/naming.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../daily/daily_note.dart';

/// Shared dialogs/actions for creating, renaming and deleting vault items.
class NoteActions {
  NoteActions._();

  static Future<void> newNote(
    BuildContext context,
    WidgetRef ref, {
    String dirRel = '',
  }) async {
    final store = ref.read(vaultStoreProvider);
    if (store == null) return;
    final title = await _prompt(
      context,
      title: 'New note',
      hint: 'Note title',
      ok: 'Create',
    );
    if (title == null || title.trim().isEmpty || !context.mounted) return;
    final name = noteFileName(title.trim(), DateTime.now());
    final rel = dirRel.isEmpty ? name : '$dirRel/$name';
    await store.writeNote(rel, newNoteTemplate(title.trim(), DateTime.now()));
    ref.read(openPathProvider.notifier).state = rel;
    ref.read(editModeProvider.notifier).state = true;
  }

  static Future<void> newFolder(
    BuildContext context,
    WidgetRef ref, {
    String dirRel = '',
  }) async {
    final store = ref.read(vaultStoreProvider);
    if (store == null) return;
    final name = await _prompt(
      context,
      title: 'New folder',
      hint: 'Folder name',
      ok: 'Create',
    );
    if (name == null || name.trim().isEmpty) return;
    final rel = dirRel.isEmpty ? name.trim() : '$dirRel/${name.trim()}';
    await store.createFolder(rel);
  }

  static Future<void> rename(
    BuildContext context,
    WidgetRef ref,
    String relPath,
    bool isDir,
  ) async {
    final store = ref.read(vaultStoreProvider);
    if (store == null) return;
    final oldName = relPath.split('/').last;
    final name = await _prompt(
      context,
      title: 'Rename',
      hint: 'New name',
      ok: 'Rename',
      initial: oldName,
    );
    if (name == null || name.trim().isEmpty || name.trim() == oldName) return;
    final parent = store.parentOf(relPath);
    final to = parent.isEmpty ? name.trim() : '$parent/${name.trim()}';
    await store.rename(relPath, to);
    if (ref.read(openPathProvider) == relPath) {
      ref.read(openPathProvider.notifier).state = to;
    }
  }

  static Future<void> delete(
    BuildContext context,
    WidgetRef ref,
    String relPath,
  ) async {
    final store = ref.read(vaultStoreProvider);
    if (store == null) return;
    final name = relPath.split('/').last;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => EscapePop(
        child: AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "$name"? This removes the file from disk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
        ),
      ),
    );
    if (ok != true) return;
    await store.delete(relPath);
    if (ref.read(openPathProvider) == relPath) {
      ref.read(openPathProvider.notifier).state = null;
    }
  }

  static Future<String?> _prompt(
    BuildContext context, {
    required String title,
    required String hint,
    required String ok,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => EscapePop(
        child: AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ok),
          ),
        ],
        ),
      ),
    );
  }
}

/// Creates/opens today's daily log (`yyyymmdd/yyyymmdd_Work_Log.md`).
Future<void> openDailyLog(BuildContext context, WidgetRef ref) async {
  final store = ref.read(vaultStoreProvider);
  if (store == null) return;
  final rel = await createDailyLog(store, DateTime.now());
  ref.read(openPathProvider.notifier).state = rel;
}
