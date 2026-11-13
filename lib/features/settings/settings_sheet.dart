import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/providers.dart';
import '../../core/vault_config.dart';
import '../../core/widgets.dart';
import '../vault/backup.dart';

bool _settingsVisible = false;

/// Bottom-sheet (mobile) / dialog (desktop) with theme picker + vault
/// actions. Ctrl/Cmd+, toggles — reopening while visible closes it
/// instead of stacking another sheet.
Future<void> showSettings(BuildContext context) {
  if (_settingsVisible) {
    Navigator.of(context).maybePop();
    return Future.value();
  }
  _settingsVisible = true;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SettingsSheet(),
  ).whenComplete(() => _settingsVisible = false);
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 64.0,
      LogicalKeyboardKey.arrowUp => -64.0,
      LogicalKeyboardKey.pageDown => 420.0,
      LogicalKeyboardKey.pageUp => -420.0,
      LogicalKeyboardKey.end => _scroll.position.maxScrollExtent + 1,
      LogicalKeyboardKey.home => -_scroll.position.maxScrollExtent - 1,
      _ => 0.0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    final pos = _scroll.position;
    _scroll.animateTo(
      (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(brainThemeProvider);
    final vaultPath = ref.watch(vaultPathProvider);
    final config = ref.watch(vaultConfigProvider);

    return EscapePop(
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Theme',
              style: TextStyle(
                color: theme.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in brainThemes)
                  _ThemeChip(
                    t: t,
                    selected: t.name == theme.name,
                    onTap: () =>
                        ref.read(brainThemeProvider.notifier).set(t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Editor',
              style: TextStyle(
                color: theme.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Autosave every ${config.autosaveMs} ms',
                    style: TextStyle(color: theme.text, fontSize: 12.5),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Slider(
                    value: config.autosaveMs.toDouble(),
                    min: VaultConfig.minAutosaveMs.toDouble(),
                    max: VaultConfig.maxAutosaveMs.toDouble(),
                    onChanged: (v) => ref
                        .read(vaultConfigProvider.notifier)
                        .preview(config.copyWith(autosaveMs: v.round())),
                    onChangeEnd: (v) => ref
                        .read(vaultConfigProvider.notifier)
                        .update(config.copyWith(autosaveMs: v.round())),
                  ),
                ),
              ],
            ),
            Text(
              'Zoom ${(config.zoom * 100).round()}% '
              '(Ctrl/Cmd+= / Ctrl/Cmd+-, Ctrl/Cmd+Shift+0 resets)',
              style: TextStyle(color: theme.text, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Saved to .purplebrain/config.json in this vault.',
              style: TextStyle(color: theme.textDim, fontSize: 11),
            ),
            const SizedBox(height: 20),
            Text(
              'Vault',
              style: TextStyle(
                color: theme.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              vaultPath ?? 'none',
              style: TextStyle(color: theme.textDim, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await exportVaultBackup(context, ref);
                  },
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Export backup'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await importVaultBackup(context, ref);
                  },
                  icon: const Icon(Icons.unarchive_outlined, size: 16),
                  label: const Text('Import backup'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(vaultPathProvider.notifier)
                        .clear();
                  },
                  icon: const Icon(Icons.door_front_door_outlined, size: 16),
                  label: const Text('Close vault'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Keyboard shortcuts',
              style: TextStyle(
                color: theme.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final (keys, action) in _shortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(
                        keys,
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(color: theme.text, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

const _shortcuts = [
  ('Ctrl/Cmd+P  ·  K', 'Quick open — find files'),
  ('Ctrl/Cmd+N', 'New note'),
  ('Ctrl/Cmd+Shift+N', 'New folder'),
  ('Ctrl/Cmd+D', 'Today\'s daily log'),
  ('Ctrl/Cmd+E', 'Toggle edit / preview'),
  ('Ctrl/Cmd+0', 'Focus sidebar'),
  ('Ctrl/Cmd+1', 'Focus editor'),
  ('Ctrl/Cmd+B', 'Collapse / expand sidebar'),
  ('Ctrl/Cmd+=  ·  -', 'Zoom in / out'),
  ('Ctrl/Cmd+Shift+0', 'Reset zoom'),
  ('Tab  /  Shift+Tab', 'Indent / dedent lines in editor'),
  ('Ctrl/Cmd+,', 'Settings (toggle)'),
  ('Arrows / Enter', 'Move around the sidebar'),
  ('↑ ↓ PgUp PgDn', 'Scroll this sheet'),
  ('Esc', 'Close dialogs and sheets'),
];

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.t,
    required this.selected,
    required this.onTap,
  });

  final BrainTheme t;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? t.accent : t.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              t.name,
              style: TextStyle(color: t.text, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
