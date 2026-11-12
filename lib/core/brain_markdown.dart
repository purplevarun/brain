import 'package:markdown/markdown.dart' as md;

/// `> [!type]` callout blocks (Obsidian/GitHub alert syntax). Produces a
/// `<callout>` element carrying the type and the raw inner markdown so the
/// builder can render nested content itself.
class CalloutSyntax extends md.BlockSyntax {
  static final _start = RegExp(
    r'^\s{0,3}>\s*\[!([A-Za-z]+)\][+-]?\s*(.*)$',
  );
  static final _cont = RegExp(r'^\s{0,3}> ?');

  const CalloutSyntax();

  @override
  RegExp get pattern => _start;

  @override
  md.Node parse(md.BlockParser parser) {
    final match = _start.firstMatch(parser.current.content)!;
    final type = match.group(1)!.toLowerCase();
    final title = match.group(2)!.trim();
    parser.advance();
    final inner = <String>[];
    while (!parser.isDone) {
      final m = _cont.firstMatch(parser.current.content);
      if (m == null) break;
      inner.add(parser.current.content.substring(m.end));
      parser.advance();
    }
    return md.Element('callout', [])
      ..attributes['type'] = type
      ..attributes['title'] = title
      ..attributes['source'] = inner.join('\n');
  }
}

/// Read-support for `[[target]]` and `[[target|alias]]` wikilinks found in
/// existing vaults — renders as a note link. brain itself only writes
/// standard markdown links.
class WikilinkSyntax extends md.InlineSyntax {
  WikilinkSyntax() : super(r'\[\[([^\[\]|]+)(?:\|([^\[\]]+))?\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final target = match.group(1)!.trim();
    final alias = match.group(2)?.trim();
    final el = md.Element.text('wikilink', alias ?? target);
    el.attributes['target'] = target;
    parser.addNode(el);
    return true;
  }
}

/// Rewrites standalone `![[name.ext]]` embed lines to standard `![](name.ext)`
/// so the normal image path renders them (videos included). Embeds that share
/// a line with other text are left alone.
String preprocessEmbeds(String body) => body.replaceAllMapped(
      RegExp(r'^\s*!\[\[([^\[\]]+)\]\]\s*$', multiLine: true),
      (m) => '![](${m.group(1)})',
    );

/// gitHubFlavored + brain's own syntaxes.
md.ExtensionSet brainExtensionSet() => md.ExtensionSet(
      [
        ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        const CalloutSyntax(),
      ],
      [
        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        WikilinkSyntax(),
      ],
    );

const _videoExts = {'mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'};
const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};

bool isVideoPath(String path) =>
    _videoExts.contains(path.split('.').last.toLowerCase());

bool isImagePath(String path) =>
    _imageExts.contains(path.split('.').last.toLowerCase());
