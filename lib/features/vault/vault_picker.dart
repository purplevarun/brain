import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/platform_utils.dart';
import '../../core/providers.dart';
import 'backup.dart';

/// First-run screen: pick an existing folder as the vault, create a new one,
/// or use the app's local vault (mobile default).
class VaultPicker extends ConsumerWidget {
  const VaultPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.psychology, size: 64, color: theme.accent),
              const SizedBox(height: 16),
              Text(
                'brain',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A local-first work log.\nYour notes live as plain markdown files in a folder you own.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textDim,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _VaultButton(
                theme: theme,
                icon: Icons.folder_open,
                label: 'Open a vault folder',
                onTap: () => _pickFolder(context, ref),
              ),
              const SizedBox(height: 10),
              _VaultButton(
                theme: theme,
                icon: Icons.create_new_folder_outlined,
                label: 'Create a new vault',
                onTap: () => _createVault(context, ref),
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 10),
                _VaultButton(
                  theme: theme,
                  icon: Icons.phone_iphone,
                  label: 'Use local vault',
                  onTap: () => _localVault(ref),
                ),
              ],
              const SizedBox(height: 10),
              _VaultButton(
                theme: theme,
                icon: Icons.unarchive_outlined,
                label: 'Import vault backup (.zip)',
                onTap: () => importVaultZip(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose your vault folder',
    );
    if (path != null) {
      await ref.read(vaultPathProvider.notifier).set(path);
    }
  }

  Future<void> _createVault(BuildContext context, WidgetRef ref) async {
    final parent = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose where to create the vault',
    );
    if (parent == null || !context.mounted) return;
    final dir = Directory(p.join(parent, 'brain_vault'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'README.md')).writeAsString(
      '# brain vault\n\nYour notes live here as plain markdown files.\n',
    );
    await ref.read(vaultPathProvider.notifier).set(dir.path);
  }

  Future<void> _localVault(WidgetRef ref) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'vault'));
    await dir.create(recursive: true);
    await ref.read(vaultPathProvider.notifier).set(dir.path);
  }
}

class _VaultButton extends StatelessWidget {
  const _VaultButton({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final BrainTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.text,
        side: BorderSide(color: theme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
