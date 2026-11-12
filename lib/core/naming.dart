import 'package:intl/intl.dart';

/// File/folder naming helpers matching the vault convention:
/// `yyyymmdd/` day folders and `yyyymmdd_Title_Words.ext` files.
String yyyymmdd(DateTime d) => DateFormat('yyyyMMdd').format(d);

/// `Prisma ML mockups: meeting!` -> `Prisma_ML_Mockups_Meeting`
String slugifyTitle(String title) {
  final words = title
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1));
  return words.join('_');
}

/// `yyyymmdd_Title_Words.md` — keeps chronological sorting by name.
String noteFileName(String title, DateTime now) {
  final slug = slugifyTitle(title);
  return slug.isEmpty
      ? '${yyyymmdd(now)}_Untitled.md'
      : '${yyyymmdd(now)}_$slug.md';
}

String dailyLogRelPath(DateTime d) {
  final day = yyyymmdd(d);
  return '$day/${day}_Work_Log.md';
}

String dailyLogTemplate(DateTime d, {String? previousLogName}) {
  final iso = DateFormat('yyyy-MM-dd').format(d);
  final weekday = DateFormat('EEEE').format(d);
  final prev = previousLogName != null ? 'previous: "$previousLogName"\n' : '';
  return '---\n'
      'title: Work Log $iso\n'
      'type: work-log\n'
      'date: $iso\n'
      'weekday: $weekday\n'
      'tags:\n'
      '  - work-log\n'
      '${prev}next:\n'
      '---\n\n'
      '# $iso · $weekday\n\n- ';
}

String newNoteTemplate(String title, DateTime now) {
  final iso = DateFormat('yyyy-MM-dd').format(now);
  return '---\n'
      'title: $title\n'
      'date: $iso\n'
      'tags: []\n'
      '---\n\n'
      '# $title\n\n';
}

/// Fills the `next:` frontmatter field of a previous daily log so the
/// previous/next chain stays linked when a new day is created.
String fillNextField(String content, String nextLogName) {
  final lines = content.split('\n');
  final fmEnd = lines.length > 1 && lines.first.trim() == '---'
      ? lines.indexOf('---', 1)
      : -1;
  if (fmEnd < 0) return content;
  for (var i = 1; i < fmEnd; i++) {
    if (lines[i].startsWith('next:')) {
      lines[i] = 'next: "$nextLogName"';
      return lines.join('\n');
    }
  }
  lines.insert(fmEnd, 'next: "$nextLogName"');
  return lines.join('\n');
}
