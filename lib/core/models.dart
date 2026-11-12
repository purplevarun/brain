/// A file or folder inside the vault, [relPath] always uses '/' separators.
class VaultNode {
  const VaultNode({
    required this.name,
    required this.relPath,
    required this.isDir,
    this.children = const [],
  });

  final String name;
  final String relPath;
  final bool isDir;
  final List<VaultNode> children;

  bool get isMarkdown => name.toLowerCase().endsWith('.md');

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Parsed YAML frontmatter of a note.
class NoteMeta {
  const NoteMeta({required this.fields});

  final Map<String, dynamic> fields;

  String? get title => fields['title']?.toString();
  String? get date => fields['date']?.toString();
  String? get type => fields['type']?.toString();

  List<String> get tags {
    final raw = fields['tags'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return [raw];
    return const [];
  }

  bool get isEmpty => fields.isEmpty;
}

class ParsedNote {
  const ParsedNote({
    required this.meta,
    required this.body,
    required this.hasFrontmatter,
  });

  final NoteMeta meta;
  final String body;
  final bool hasFrontmatter;
}

class SearchHit {
  const SearchHit({
    required this.path,
    required this.line,
    required this.snippet,
  });

  final String path;
  final int line;
  final String snippet;
}
