import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/providers.dart';
import '../vault/backup.dart';

/// Bottom-sheet (mobile) / dialog (desktop) with theme picker + vault actions.
Future<void> showSettings(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    final vaultPath = ref.watch(vaultPathProvider);

    return SafeArea(
      child: SingleChildScrollView(
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
          ],
        ),
      ),
    );
  }
}

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
