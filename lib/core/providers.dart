import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/search/search_service.dart';
import 'frontmatter.dart';
import 'models.dart';
import 'vault_config.dart';
import 'vault_store.dart';

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// Absolute path of the open vault, or null when none is picked yet.
final vaultPathProvider = NotifierProvider<VaultPathNotifier, String?>(
  VaultPathNotifier.new,
);

class VaultPathNotifier extends Notifier<String?> {
  static const _key = 'vault_path';

  @override
  String? build() {
    final p = ref.read(sharedPrefsProvider).getString(_key);
    if (p == null) return null;
    return p;
  }

  Future<void> set(String path) async {
    state = path;
    await ref.read(sharedPrefsProvider).setString(_key, path);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(sharedPrefsProvider).remove(_key);
  }
}

final vaultStoreProvider = Provider<VaultStore?>((ref) {
  final path = ref.watch(vaultPathProvider);
  return path == null ? null : VaultStore(path);
});

/// Live file tree, refreshed on filesystem changes.
final treeProvider = StreamProvider<VaultNode?>((ref) {
  final store = ref.watch(vaultStoreProvider);
  if (store == null) return const Stream.empty();
  return store.watchTree();
});

/// Flat list of all file relPaths.
final allFilesProvider = FutureProvider<List<String>>((ref) async {
  final store = ref.watch(vaultStoreProvider);
  if (store == null) return const [];
  ref.watch(treeProvider); // re-fetch when the tree changes
  return store.listAllFiles();
});

/// Currently open note relPath.
final openPathProvider = StateProvider<String?>((ref) => null);

/// Raw file contents for a relPath.
final noteContentProvider = FutureProvider.family<String, String>((
  ref,
  relPath,
) async {
  final store = ref.read(vaultStoreProvider);
  if (store == null) return '';
  return store.readNote(relPath);
});

/// true = raw editor, false = rendered preview.
final editModeProvider = StateProvider<bool>((ref) => false);

/// Unsaved-changes indicator for the open note.
final noteDirtyProvider = StateProvider<bool>((ref) => false);

/// Sidebar tab: 0 files, 1 search, 2 tags.
final sidebarTabProvider = StateProvider<int>((ref) => 0);

/// Lets app-level actions (shortcuts, menus) invoke editor ops.
final editorActionsProvider = StateProvider<EditorActions?>((ref) => null);

abstract class EditorActions {
  Future<void> save();
  void insertAtCursor(String text);
  Future<void> attachFiles();
}

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final store = ref.watch(vaultStoreProvider);
  final query = ref.watch(searchQueryProvider).trim();
  if (store == null || query.isEmpty) return const [];
  return searchNotes(store, query);
});

/// tag -> sorted note paths, from frontmatter tags and inline #tags.
final tagsProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final store = ref.watch(vaultStoreProvider);
  if (store == null) return const {};
  final files = await ref.watch(allFilesProvider.future);
  final tags = <String, Set<String>>{};
  for (final rel in files) {
    if (!rel.toLowerCase().endsWith('.md')) continue;
    String raw;
    try {
      raw = await store.readNote(rel);
    } catch (_) {
      continue;
    }
    final note = parseNote(raw);
    for (final tag in extractTags(note.meta, note.body)) {
      tags.putIfAbsent(tag, () => {}).add(rel);
    }
  }
  return tags.map((k, v) => MapEntry(k, v.toList()..sort()));
});

/// Tag currently selected in the tags tab.
final tagFilterProvider = StateProvider<String?>((ref) => null);

/// Collapse state of the desktop sidebar.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Per-vault config (`.purplebrain/config.json`). Reloaded whenever the
/// vault path changes.
final vaultConfigProvider =
    NotifierProvider<VaultConfigNotifier, VaultConfig>(
  VaultConfigNotifier.new,
);

class VaultConfigNotifier extends Notifier<VaultConfig> {
  @override
  VaultConfig build() {
    final path = ref.watch(vaultPathProvider);
    return path == null ? VaultConfig.defaultConfig : VaultConfig.load(path);
  }

  Future<void> update(VaultConfig config) async {
    state = config;
    final path = ref.read(vaultPathProvider);
    if (path != null) await config.save(path);
  }
}

/// Focus targets for the Cmd+0 / Cmd+1 pane-focus shortcuts.
final sidebarFocusProvider = Provider<FocusNode>((ref) => FocusNode());
final editorFocusProvider = Provider<FocusNode>((ref) => FocusNode());
