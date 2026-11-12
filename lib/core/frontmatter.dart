import 'package:yaml/yaml.dart';

import 'models.dart';

final _frontmatterRe = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*(?:\n|$)');

/// Splits a raw markdown document into parsed frontmatter + body.
ParsedNote parseNote(String raw) {
  final match = _frontmatterRe.firstMatch(raw);
  if (match == null) {
    return ParsedNote(
      meta: const NoteMeta(fields: {}),
      body: raw,
      hasFrontmatter: false,
    );
  }
  Map<String, dynamic> fields = {};
  try {
    final doc = loadYaml(match.group(1)!);
    if (doc is YamlMap) {
      fields = doc.map((k, v) => MapEntry(k.toString(), _unwrap(v)));
    }
  } catch (_) {
    // malformed frontmatter — treat as body-only note
  }
  return ParsedNote(
    meta: NoteMeta(fields: fields),
    body: raw.substring(match.end),
    hasFrontmatter: true,
  );
}

dynamic _unwrap(dynamic v) => switch (v) {
  YamlMap m => m.map((k, e) => MapEntry(k.toString(), _unwrap(e))),
  YamlList l => l.map(_unwrap).toList(),
  _ => v,
};

/// Strips fenced code blocks so `#tag` inside code is not indexed.
String stripCodeBlocks(String body) =>
    body.replaceAll(RegExp(r'```[\s\S]*?(```|$)'), ' ');

final _inlineTagRe = RegExp(r'(?<![\w/#])#([A-Za-z][\w/-]*)');

/// Frontmatter tags + inline `#tag` found in the body, lowercased, deduped.
Set<String> extractTags(NoteMeta meta, String body) {
  final tags = <String>{
    for (final t in meta.tags) t.toLowerCase(),
  };
  for (final m in _inlineTagRe.allMatches(stripCodeBlocks(body))) {
    tags.add(m.group(1)!.toLowerCase());
  }
  return tags;
}
