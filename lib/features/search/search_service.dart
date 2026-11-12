import '../../core/models.dart';
import '../../core/vault_store.dart';

/// Full-text search over every .md file in the vault. Returns up to 200 hits,
/// one per matching line, newest-day paths first (paths sort naturally since
/// names start with yyyymmdd).
Future<List<SearchHit>> searchNotes(VaultStore store, String query) async {
  final q = query.toLowerCase();
  final files = await store.listAllFiles();
  files.sort((a, b) => b.compareTo(a));
  final hits = <SearchHit>[];
  for (final rel in files) {
    if (!rel.toLowerCase().endsWith('.md')) continue;
    String raw;
    try {
      raw = await store.readNote(rel);
    } catch (_) {
      continue;
    }
    final lines = raw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains(q)) {
        hits.add(SearchHit(path: rel, line: i + 1, snippet: lines[i].trim()));
        if (hits.length >= 200) return hits;
      }
    }
  }
  return hits;
}
