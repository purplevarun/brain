import 'dart:io';

import 'package:brain/core/providers.dart';
import 'package:brain/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Regression seam for the Cmd+0 / Cmd+1 pane-focus shortcuts: send real
/// hardware key events through the global handler and assert the focus
/// actually lands on the sidebar / editor nodes.
void main() {
  late Directory tmp;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('brain_focus');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  // Matches _Shortcuts._modifier: Cmd on macOS, Ctrl elsewhere.
  final modifier = !kIsWeb && Platform.isMacOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;

  Future<void> sendChord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Cmd+0 and Cmd+1 move focus between sidebar and editor', (
    tester,
  ) async {
    final vault = Directory(p.join(tmp.path, 'focus_vault'))..createSync();
    File(p.join(vault.path, 'note.md')).writeAsStringSync('# hi');
    SharedPreferences.setMockInitialValues({'vault_path': vault.path});
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const BrainApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(BrainApp)));
    container.read(openPathProvider.notifier).state = 'note.md';
    container.read(editModeProvider.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final sidebarFocus = container.read(sidebarFocusProvider);
    final editorFocus = container.read(editorFocusProvider);

    await sendChord(tester, LogicalKeyboardKey.digit1);
    expect(editorFocus.hasFocus, isTrue, reason: 'Cmd+1 focuses editor');

    await sendChord(tester, LogicalKeyboardKey.digit0);
    // Focus must land on a real focusable row inside the sidebar —
    // the wrapper node alone is an invisible dead end.
    expect(sidebarFocus.hasFocus || _descendantHasFocus(sidebarFocus),
        isTrue,
        reason: 'Cmd+0 focuses inside the sidebar');
    expect(_focusedNode(container), isNot(sidebarFocus),
        reason: 'a concrete row/header holds focus, not the wrapper');

    await sendChord(tester, LogicalKeyboardKey.digit1);
    expect(editorFocus.hasFocus, isTrue, reason: 'Cmd+1 refocuses editor');
  });

  testWidgets('Cmd+0 expands a collapsed sidebar, then focuses it', (
    tester,
  ) async {
    final vault = Directory(p.join(tmp.path, 'collapsed_vault'))
      ..createSync();
    File(p.join(vault.path, 'note.md')).writeAsStringSync('# hi');
    SharedPreferences.setMockInitialValues({'vault_path': vault.path});
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const BrainApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(BrainApp)));
    container.read(sidebarCollapsedProvider.notifier).state = true;
    await tester.pump();

    await sendChord(tester, LogicalKeyboardKey.digit0);
    await tester.pump();

    expect(container.read(sidebarCollapsedProvider), isFalse,
        reason: 'Cmd+0 expands the sidebar');
    final sidebarFocus = container.read(sidebarFocusProvider);
    expect(sidebarFocus.hasFocus || _descendantHasFocus(sidebarFocus),
        isTrue,
        reason: 'focus lands inside the freshly-expanded sidebar');
  });

  testWidgets('Cmd+1 with no open note opens quick open instead of no-op', (
    tester,
  ) async {
    final vault = Directory(p.join(tmp.path, 'empty_vault'))..createSync();
    SharedPreferences.setMockInitialValues({'vault_path': vault.path});
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const BrainApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // showQuickOpen awaits real file IO (allFilesProvider) before showing
    // the dialog — needs the real event loop, not fake-async pumps.
    await tester.runAsync(() async {
      await sendChord(tester, LogicalKeyboardKey.digit1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsOneWidget,
        reason: 'Cmd+1 with no note offers quick open');
  });
}

bool _descendantHasFocus(FocusNode node) =>
    node.descendants.any((d) => d.hasFocus);

FocusNode? _focusedNode(ProviderContainer container) =>
    FocusManager.instance.primaryFocus;
