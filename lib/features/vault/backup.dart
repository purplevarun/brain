import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/platform_utils.dart';
import '../../core/providers.dart';

/// Brain backups are `.purplebrain` files: a plain ZIP archive of the vault
/// folder (notes + attachments, dotfiles skipped). Rename to `.zip` to inspect
/// with any archive tool — there is no database or proprietary format inside.
const backupExtension = 'purplebrain';

/// Zip the vault into bytes — pure logic, no UI, so tests can exercise it.
Future<Uint8List> buildVaultArchive(String root) async {
  final archive = Archive();
  await for (final entity in Directory(
    root,
  ).list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: root);
    if (rel.split(p.separator).any((s) => s.startsWith('.'))) continue;
    archive.addFile(
      ArchiveFile(
        rel.replaceAll(p.separator, '/'),
        await entity.length(),
        await entity.readAsBytes(),
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Extract archive bytes into [targetRoot]. Returns the file count. Entries
/// that could escape the target or hide dot-paths are skipped.
Future<int> extractVaultArchive(Uint8List bytes, String targetRoot) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  var count = 0;
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final safe = entry.name.replaceAll('\\', '/');
    if (safe.split('/').any((s) => s == '..' || s.startsWith('.'))) continue;
    final out = File(p.joinAll([targetRoot, ...safe.split('/')]));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(entry.content as List<int>);
    count++;
  }
  return count;
}

/// Export the vault as a `.purplebrain` backup — save dialog on desktop,
/// share sheet on mobile.
Future<void> exportVaultBackup(BuildContext context, WidgetRef ref) async {
  final store = ref.read(vaultStoreProvider);
  if (store == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final name = 'brain_vault_$stamp.$backupExtension';

  try {
    final bytes = await buildVaultArchive(store.root);

    if (isDesktop) {
      // The picker writes [bytes] to the user-chosen path itself.
      await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: 'application/zip',
        dialogTitle: 'Export vault backup (.purplebrain)',
      );
    } else {
      final tmp = await getTemporaryDirectory();
      final f = File(p.join(tmp.path, name));
      await f.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], text: 'brain vault backup'),
      );
    }
    messenger.showSnackBar(const SnackBar(content: Text('Vault exported.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

/// Restore a vault from a `.purplebrain` (or legacy `.zip`) backup: desktop
/// extracts into a picked folder, mobile into the app-documents vault.
Future<void> importVaultBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [backupExtension, 'zip'],
      dialogTitle: 'Choose a .purplebrain backup',
    );
    final file = picked.firstOrNull;
    if (file == null) return;

    final bytes = await file.readAsBytes();

    String targetRoot;
    if (isDesktop) {
      final dir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Extract vault into this folder',
      );
      if (dir == null) return;
      targetRoot = dir;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      targetRoot = p.join(docs.path, 'vault');
    }

    final count = await extractVaultArchive(bytes, targetRoot);
    await ref.read(vaultPathProvider.notifier).set(targetRoot);
    messenger.showSnackBar(
      SnackBar(content: Text('Vault imported ($count files).')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}
