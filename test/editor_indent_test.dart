import 'package:brain/features/editor/indent.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('indentSelection', () {
    test('collapsed cursor + tab inserts two spaces', () {
      final v = indentSelection(
        const TextEditingValue(
          text: 'hello',
          selection: TextSelection.collapsed(offset: 5),
        ),
        dedent: false,
      );
      expect(v.text, 'hello  ');
      expect(v.selection.baseOffset, 7);
    });

    test('tab with selection indents every touched line', () {
      final v = indentSelection(
        const TextEditingValue(
          text: 'a\nb\nc',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
        ),
        dedent: false,
      );
      expect(v.text, '  a\n  b\nc');
      expect(v.selection.baseOffset, 0);
      expect(v.selection.extentOffset, 7);
    });

    test('indent skips blank lines', () {
      final v = indentSelection(
        const TextEditingValue(
          text: 'a\n\nb',
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
        ),
        dedent: false,
      );
      expect(v.text, '  a\n\n  b');
    });

    test('shift+tab dedents each line by one level', () {
      final v = indentSelection(
        const TextEditingValue(
          text: '  a\n    b\n\tc',
          selection: TextSelection(baseOffset: 0, extentOffset: 12),
        ),
        dedent: true,
      );
      expect(v.text, 'a\n  b\nc');
    });

    test('collapsed cursor + shift+tab dedents only that line', () {
      final v = indentSelection(
        const TextEditingValue(
          text: '  a\n  b',
          selection: TextSelection.collapsed(offset: 3),
        ),
        dedent: true,
      );
      expect(v.text, 'a\n  b');
      expect(v.selection.baseOffset, 1);
    });

    test('dedent on unindented line leaves caret at line start', () {
      final v = indentSelection(
        const TextEditingValue(
          text: 'abc\ndef',
          selection: TextSelection.collapsed(offset: 5),
        ),
        dedent: true,
      );
      expect(v.text, 'abc\ndef');
      expect(v.selection.baseOffset, 5);
    });
  });
}
