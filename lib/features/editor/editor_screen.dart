import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/brain_mark.dart';
import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/brain_markdown.dart';
import '../../core/platform_utils.dart';
import '../../core/providers.dart';
import '../preview/note_preview.dart';
import 'indent.dart';

final _checkboxRe = RegExp(r'^\s*[-*+] \[( |x|X)\]', multiLine: true);

/// Raw markdown editor with syntax highlighting, autosave, attachments and
/// an edit/preview toggle.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    implements EditorActions {
  late _MarkdownEditingController _controller;
  Timer? _autosave;
  String? _loadedPath;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _controller = _MarkdownEditingController(ref.read(brainThemeProvider));
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(editorActionsProvider.notifier).state = this;
    });
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_loadedPath == null) return;
    if (mounted) ref.read(noteDirtyProvider.notifier).state = true;
    _autosave?.cancel();
    final ms = ref.read(vaultConfigProvider).autosaveMs;
    _autosave = Timer(Duration(milliseconds: ms), () => save());
  }

  @override
  Future<void> save() async {
    final path = _loadedPath;
    final store = ref.read(vaultStoreProvider);
    if (path == null || store == null) return;
    await store.writeNote(path, _controller.text);
    if (mounted) ref.read(noteDirtyProvider.notifier).state = false;
  }

  @override
  void insertAtCursor(String text) {
    final sel = _controller.selection;
    final base = sel.isValid ? sel.start : _controller.text.length;
    final end = sel.isValid ? sel.end : base;
    _controller
      ..text = _controller.text.replaceRange(base, end, text)
      ..selection = TextSelection.collapsed(offset: base + text.length);
  }

  @override
  Future<void> attachFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    await _attachPaths(files.map((f) => f.path).whereType<String>());
  }

  Future<void> _attachPaths(Iterable<String> paths) async {
    final store = ref.read(vaultStoreProvider);
    final note = _loadedPath;
    if (store == null || note == null) return;
    final dirRel = store.parentOf(note);
    for (final src in paths) {
      final rel = await store.importFile(src, dirRel);
      final name = rel.split('/').last;
      final insert = (isImagePath(name) || isVideoPath(name))
          ? '![]($name)'
          : '[$name]($name)';
      insertAtCursor('$insert\n');
    }
  }

  /// Toggles the n-th `- [ ]` / `- [x]` checkbox in the raw source.
  void toggleCheckbox(int index) {
    var i = 0;
    final text = _controller.text;
    final newText = text.replaceAllMapped(_checkboxRe, (m) {
      if (i++ != index) return m.group(0)!;
      return m.group(0)!.contains('[ ]')
          ? m.group(0)!.replaceFirst('[ ]', '[x]')
          : m.group(0)!.replaceFirst(RegExp(r'\[(x|X)\]'), '[ ]');
    });
    if (newText != text) {
      _controller.text = newText;
      save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(brainThemeProvider);
    final openPath = ref.watch(openPathProvider);
    final store = ref.watch(vaultStoreProvider);

    ref.listen(openPathProvider, (prev, next) async {
      if (prev != next && prev != null) await save();
      _loadedPath = next;
      if (next != null && store != null) {
        try {
          final content = await store.readNote(next);
          if (mounted && _loadedPath == next) {
            _controller.text = content;
            ref.read(noteDirtyProvider.notifier).state = false;
          }
        } catch (_) {
          _controller.text = '';
        }
      }
    });

    if (openPath == null || store == null) {
      return _EmptyEditor(theme: theme);
    }

    // Initial load for the first file opened after this widget mounts.
    if (_loadedPath != openPath) {
      _loadedPath = openPath;
      store.readNote(openPath).then((content) {
        if (mounted && _loadedPath == openPath) {
          _controller.text = content;
          ref.read(noteDirtyProvider.notifier).state = false;
        }
      });
    }

    ref.listen(brainThemeProvider, (prev, next) {
      if (prev?.name == next.name) return;
      _controller.theme = next;
    });

    final editMode = ref.watch(editModeProvider);
    final dirty = ref.watch(noteDirtyProvider);

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) => _attachPaths(
        details.files.map((f) => f.path),
      ),
      child: Column(
        children: [
          _EditorHeader(
            relPath: openPath,
            dirty: dirty,
            editMode: editMode,
            theme: theme,
            onAttach: attachFiles,
            onSetMode: (edit) =>
                ref.read(editModeProvider.notifier).state = edit,
          ),
          Expanded(
            child: editMode
                ? _buildEditor(theme)
                : NotePreview(
                    relPath: openPath,
                    raw: _controller.text,
                    onToggleCheckbox: toggleCheckbox,
                  ),
          ),
          if (_dragging)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              color: theme.accent.withValues(alpha: 0.15),
              child: Text(
                'Drop to attach into ${store.parentOf(openPath).isEmpty ? 'vault root' : store.parentOf(openPath)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.accent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor(BrainTheme theme) {
    return Container(
      color: theme.bg,
      child: Focus(
        // Catch Tab before focus-traversal sees it: indent / dedent instead.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.tab) {
            _controller.value = indentSelection(
              _controller.value,
              dedent: HardwareKeyboard.instance.isShiftPressed,
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: ref.read(editorFocusProvider),
          expands: true,
          maxLines: null,
          minLines: null,
          keyboardType: TextInputType.multiline,
          cursorColor: theme.accent,
          smartQuotesType: SmartQuotesType.disabled,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13.5,
            height: 1.5,
            color: theme.text,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          ),
        ),
      ),
    );
  }
}

class _HighlightRule {
  const _HighlightRule(this.pattern, this.style);
  final RegExp pattern;
  final TextStyle style;
}

/// A [TextEditingController] that colors markdown syntax inline. Earlier rules
/// win when ranges overlap (fences and frontmatter beat inline patterns).
class _MarkdownEditingController extends TextEditingController {
  _MarkdownEditingController(this._theme);

  BrainTheme _theme;
  List<_HighlightRule>? _rules;

  set theme(BrainTheme value) {
    _theme = value;
    _rules = null;
    notifyListeners();
  }

  List<_HighlightRule> get _highlightRules => _rules ??= [
        _HighlightRule(
          RegExp(r'^---\s*$', multiLine: true),
          TextStyle(color: _theme.purple),
        ),
        _HighlightRule(
          RegExp(r'```[\s\S]*?(```|$)', multiLine: true),
          TextStyle(color: _theme.orange, backgroundColor: _theme.codeBg),
        ),
        _HighlightRule(
          RegExp(r'^\s{0,3}#{1,6} .*$', multiLine: true),
          TextStyle(color: _theme.blue, fontWeight: FontWeight.w700),
        ),
        _HighlightRule(
          RegExp(r'^\s{0,3}>.*$', multiLine: true),
          TextStyle(color: _theme.cyan, fontStyle: FontStyle.italic),
        ),
        _HighlightRule(
          RegExp(r'\*\*[^*\n]+\*\*'),
          TextStyle(color: _theme.orange, fontWeight: FontWeight.w700),
        ),
        _HighlightRule(
          RegExp(r'~~[^~\n]+~~'),
          TextStyle(
            color: _theme.textDim,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        _HighlightRule(
          RegExp(r'`[^`\n]+`'),
          TextStyle(color: _theme.orange, backgroundColor: _theme.codeBg),
        ),
        _HighlightRule(
          RegExp(r'\*[^*\n]+\*'),
          TextStyle(color: _theme.text, fontStyle: FontStyle.italic),
        ),
        _HighlightRule(
          RegExp(r'!?\[[^\]\n]*\]\([^\)\n]*\)'),
          TextStyle(color: _theme.accent),
        ),
        _HighlightRule(
          RegExp(r'!?\[\[[^\]\n]*\]\]'),
          TextStyle(color: _theme.accent),
        ),
        _HighlightRule(
          RegExp(r'^\s*[-*+] \[ \]', multiLine: true),
          TextStyle(color: _theme.textDim),
        ),
        _HighlightRule(
          RegExp(r'^\s*[-*+] \[x\]', multiLine: true, caseSensitive: false),
          TextStyle(color: _theme.green),
        ),
        _HighlightRule(
          RegExp(r'^\s*[-*+] ', multiLine: true),
          TextStyle(color: _theme.purple),
        ),
        _HighlightRule(
          RegExp(r'^\s*\d+\. ', multiLine: true),
          TextStyle(color: _theme.purple),
        ),
        _HighlightRule(
          RegExp(r'^[\w -]+:', multiLine: true),
          TextStyle(color: _theme.blue),
        ),
        _HighlightRule(
          RegExp(r'#[A-Za-z][\w/-]*'),
          TextStyle(color: _theme.cyan),
        ),
        _HighlightRule(
          RegExp(r'https?://\S+'),
          TextStyle(color: _theme.accent),
        ),
      ];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) return TextSpan(style: style, text: '');

    final marks = List<TextStyle?>.filled(text.length, null);
    for (final rule in _highlightRules) {
      for (final m in rule.pattern.allMatches(text)) {
        for (var i = m.start; i < m.end; i++) {
          marks[i] ??= rule.style;
        }
      }
    }

    if (withComposing && value.composing.isValid) {
      const under = TextStyle(decoration: TextDecoration.underline);
      for (var i = value.composing.start;
          i < value.composing.end && i < text.length;
          i++) {
        marks[i] = marks[i]?.copyWith(decoration: TextDecoration.underline) ??
            under;
      }
    }

    final children = <InlineSpan>[];
    var start = 0;
    var cur = marks[0];
    for (var i = 1; i <= text.length; i++) {
      final next = i < text.length ? marks[i] : null;
      if (i == text.length || !identical(next, cur)) {
        children.add(TextSpan(text: text.substring(start, i), style: cur));
        start = i;
        cur = next;
      }
    }
    return TextSpan(style: style, children: children);
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.relPath,
    required this.dirty,
    required this.editMode,
    required this.theme,
    required this.onAttach,
    required this.onSetMode,
  });

  final String relPath;
  final bool dirty;
  final bool editMode;
  final BrainTheme theme;
  final VoidCallback onAttach;
  final ValueChanged<bool> onSetMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 15, color: theme.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              relPath,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.text, fontSize: 12.5),
            ),
          ),
          if (dirty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.circle, size: 8, color: theme.orange),
            ),
          _ModeToggle(editMode: editMode, theme: theme, onSet: onSetMode),
          const SizedBox(width: 8),
          _HeaderIcon(
            icon: Icons.attach_file,
            tooltip: 'Attach file',
            onTap: onAttach,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

/// Two-segment Edit | Preview pill — the Cmd/Ctrl+E state shown visibly.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.editMode,
    required this.theme,
    required this.onSet,
  });

  final bool editMode;
  final BrainTheme theme;
  final ValueChanged<bool> onSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('Edit', Icons.edit_outlined, editMode, () => onSet(true)),
          _seg('Preview', Icons.visibility_outlined, !editMode,
              () => onSet(false)),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool on, VoidCallback tap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: on ? theme.accent.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13,
                color: on ? theme.accent : theme.textDim),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: on ? theme.accent : theme.textDim,
                fontWeight: on ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final BrainTheme theme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: theme.textDim),
        ),
      ),
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({required this.theme});

  final BrainTheme theme;

  @override
  Widget build(BuildContext context) {
    final kbd = isDesktop;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrainMark(size: 56, color: theme.textDim.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'brain',
            style: TextStyle(
              color: theme.textDim,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a note on the left, or create one.',
            style: TextStyle(color: theme.textDim, fontSize: 13),
          ),
          if (kbd) ...[
            const SizedBox(height: 14),
            Text(
              'Ctrl/Cmd+P quick open · Ctrl/Cmd+N new note\nCtrl/Cmd+D daily log · Ctrl/Cmd+, settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textDim.withValues(alpha: 0.7),
                fontSize: 11.5,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
