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

/// Zip the whole vault and let the user save/share it — the "backup file"
/// story until real sync exists.
Future<void> exportVaultZip(BuildContext context, WidgetRef ref) async {
  final store = ref.read(vaultStoreProvider);
  if (store == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final name = 'brain_vault_$stamp.zip';

  final archive = Archive();
  await for (final entity in Directory(
    store.root,
  ).list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: store.root);
    if (rel.split(p.separator).any((s) => s.startsWith('.'))) continue;
    archive.addFile(
      ArchiveFile(
        rel.replaceAll(p.separator, '/'),
        await entity.length(),
        await entity.readAsBytes(),
      ),
    );
  }
  final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

  if (isDesktop) {
    // The picker writes [bytes] to the user-chosen path itself.
    await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/zip',
      dialogTitle: 'Export vault backup',
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
}

/// Restore a vault from a .zip: desktop extracts into a picked folder,
/// mobile into the app-documents vault.
Future<void> importVaultZip(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip'],
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

  final archive = ZipDecoder().decodeBytes(bytes);
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final safe = entry.name.replaceAll('\\', '/');
    if (safe.split('/').any((s) => s == '..' || s.startsWith('.'))) continue;
    final out = File(p.joinAll([targetRoot, ...safe.split('/')]));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(entry.content as List<int>);
  }
  await ref.read(vaultPathProvider.notifier).set(targetRoot);
  messenger.showSnackBar(const SnackBar(content: Text('Vault imported.')));
}
