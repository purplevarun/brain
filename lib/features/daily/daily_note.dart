import '../../core/naming.dart';
import '../../core/vault_store.dart';

/// Creates `yyyymmdd/yyyymmdd_Work_Log.md` (if missing) and returns its
/// relPath. Links back to the most recent earlier work log via `previous:`
/// and back-fills that log's `next:` field — the same convention the user's
/// obsidian work-log vault uses.
Future<String> createDailyLog(VaultStore store, DateTime day) async {
  final rel = dailyLogRelPath(day);
  final files = await store.listAllFiles();
  if (files.contains(rel)) return rel;

  final dayStr = yyyymmdd(day);
  final earlier = files
      .where((f) => RegExp(r'^\d{8}/\d{8}_Work_Log\.md$').hasMatch(f))
      .where((f) => f.compareTo(rel) < 0)
      .toList()
    ..sort();

  String? prevName;
  if (earlier.isNotEmpty) {
    final prevRel = earlier.last;
    prevName = prevRel.split('/').last;
    try {
      final prevContent = await store.readNote(prevRel);
      await store.writeNote(
        prevRel,
        fillNextField(prevContent, '${dayStr}_Work_Log.md'),
      );
    } catch (_) {}
  }

  final dirRel = rel.substring(0, rel.lastIndexOf('/'));
  await store.createFolder(dirRel);
  await store.writeNote(rel, dailyLogTemplate(day, previousLogName: prevName));
  return rel;
}
