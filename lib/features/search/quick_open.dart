import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/theme_controller.dart';
import '../../core/providers.dart';

/// Ctrl/Cmd+K fuzzy quick-open over every file in the vault.
Future<void> showQuickOpen(BuildContext context, WidgetRef ref) async {
  final files = await ref.read(allFilesProvider.future);
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _QuickOpenDialog(files: files),
  );
}

class _QuickOpenDialog extends ConsumerStatefulWidget {
  const _QuickOpenDialog({required this.files});

  final List<String> files;

  @override
  ConsumerState<_QuickOpenDialog> createState() => _QuickOpenDialogState();
}

class _QuickOpenDialogState extends ConsumerState<_QuickOpenDialog> {
  late final Fuzzy<String> _fuzzy;
  List<String> _results = const [];
  int _selected = 0;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fuzzy = Fuzzy(
      widget.files,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'path',
            weight: 1,
            getter: (s) => s,
          ),
        ],
        threshold: 0.4,
      ),
    );
    _results = widget.files.take(30).toList();
  }

  void _onQuery(String q) {
    setState(() {
      _selected = 0;
      _results = q.trim().isEmpty
          ? widget.files.take(30).toList()
          : _fuzzy
                .search(q)
                .map((r) => r.item)
                .take(30)
                .toList();
    });
  }

  void _open(String rel) {
    ref.read(openPathProvider.notifier).state = rel;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(brainThemeProvider);
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyboardListener(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: (e) {
                if (e is! KeyDownEvent) return;
                if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(
                    () => _selected = (_selected + 1) % _results.length.clamp(1, 1 << 30),
                  );
                } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(
                    () => _selected = (_selected - 1) % _results.length.clamp(1, 1 << 30),
                  );
                } else if (e.logicalKey == LogicalKeyboardKey.enter &&
                    _results.isNotEmpty) {
                  _open(_results[_selected]);
                }
              },
              child: TextField(
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Quick open — type a file name…',
                  prefixIcon: Icon(Icons.bolt, size: 18),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                onChanged: _onQuery,
                onSubmitted: (_) {
                  if (_results.isNotEmpty) _open(_results[_selected]);
                },
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final rel = _results[i];
                  final selected = i == _selected;
                  return InkWell(
                    onTap: () => _open(rel),
                    onHover: (h) {
                      if (h) setState(() => _selected = i);
                    },
                    child: Container(
                      color: selected
                          ? theme.accent.withValues(alpha: 0.14)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: Text(
                        rel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: selected ? theme.accent : theme.text,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }
}
