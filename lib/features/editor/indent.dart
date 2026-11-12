import 'package:flutter/services.dart';

const _indent = '  ';

/// Tab / Shift+Tab behaviour for the markdown editor, as a pure function on
/// [TextEditingValue] so it can be unit-tested without widgets.
///
/// - Collapsed cursor + Tab: insert two spaces at the caret.
/// - Selection (or Shift+Tab): expand to whole lines, then add/remove one
///   indent level per line. Dedent removes up to two spaces or one tab.
TextEditingValue indentSelection(
  TextEditingValue value, {
  required bool dedent,
}) {
  final text = value.text;
  var sel = value.selection;
  if (!sel.isValid) sel = TextSelection.collapsed(offset: text.length);
  final start = sel.start;
  final end = sel.end;

  if (!dedent && start == end) {
    final newText = text.replaceRange(start, end, _indent);
    return value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + _indent.length),
    );
  }

  final lineStart =
      start == 0 ? 0 : _lastNewlineBefore(text, start - 1) + 1;
  var lineEnd = text.length;
  if (end < text.length) {
    final nl = text.indexOf('\n', end);
    if (nl != -1) lineEnd = nl;
  }

  final block = text.substring(lineStart, lineEnd);
  final lines = block.split('\n');
  final out = <String>[];
  for (final line in lines) {
    if (dedent) {
      if (line.startsWith(_indent)) {
        out.add(line.substring(_indent.length));
      } else if (line.startsWith(' ') || line.startsWith('\t')) {
        out.add(line.substring(1));
      } else {
        out.add(line);
      }
    } else {
      out.add(line.isEmpty ? line : _indent + line);
    }
  }
  final newBlock = out.join('\n');
  final newText = text.replaceRange(lineStart, lineEnd, newBlock);
  final firstDelta = out.first.length - lines.first.length;

  final TextSelection newSel;
  if (start == end) {
    final caret = (start + firstDelta)
        .clamp(lineStart, lineStart + newBlock.length);
    newSel = TextSelection.collapsed(offset: caret);
  } else {
    newSel = TextSelection(
      baseOffset: lineStart,
      extentOffset: lineStart + newBlock.length,
    );
  }
  return value.copyWith(text: newText, selection: newSel);
}

int _lastNewlineBefore(String text, int from) =>
    from < 0 ? -1 : text.lastIndexOf('\n', from);
