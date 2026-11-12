import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-vault settings, stored inside the vault itself at
/// `.purplebrain/config.json` — travels with the vault (and its backups
/// intentionally skip dotfiles, so it stays private).
class VaultConfig {
  const VaultConfig({this.autosaveMs = 400});

  /// Editor flush interval. Small values make saving effectively continuous;
  /// the user tunes it in Settings.
  final int autosaveMs;

  static const minAutosaveMs = 100;
  static const maxAutosaveMs = 2000;
  static const dirName = '.purplebrain';
  static const fileName = 'config.json';

  static VaultConfig load(String vaultRoot) {
    try {
      final f = File(_path(vaultRoot));
      if (!f.existsSync()) return const VaultConfig();
      final json = jsonDecode(f.readAsStringSync());
      if (json is! Map) return const VaultConfig();
      final ms = json['autosave_ms'];
      return VaultConfig(
        autosaveMs: ms is int
            ? ms.clamp(minAutosaveMs, maxAutosaveMs)
            : defaultConfig.autosaveMs,
      );
    } catch (_) {
      return const VaultConfig();
    }
  }

  static const defaultConfig = VaultConfig();

  static String _path(String vaultRoot) =>
      p.join(vaultRoot, dirName, fileName);

  Future<void> save(String vaultRoot) async {
    final f = File(_path(vaultRoot));
    await f.parent.create(recursive: true);
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'autosave_ms': autosaveMs}),
    );
  }

  VaultConfig copyWith({int? autosaveMs}) =>
      VaultConfig(autosaveMs: autosaveMs ?? this.autosaveMs);
}
