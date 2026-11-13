import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-vault settings, stored inside the vault itself at
/// `.purplebrain/config.json` — travels with the vault (and its backups
/// intentionally skip dotfiles, so it stays private).
class VaultConfig {
  const VaultConfig({this.autosaveMs = 400, this.zoom = 1.0});

  /// Editor flush interval. Small values make saving effectively continuous;
  /// the user tunes it in Settings.
  final int autosaveMs;

  /// Whole-window zoom factor (1.0 = 100%), VS Code style.
  final double zoom;

  static const minAutosaveMs = 100;
  static const maxAutosaveMs = 2000;
  static const minZoom = 0.6;
  static const maxZoom = 2.0;
  static const zoomStep = 0.1;
  static const dirName = '.purplebrain';
  static const fileName = 'config.json';

  static VaultConfig load(String vaultRoot) {
    try {
      final f = File(_path(vaultRoot));
      if (!f.existsSync()) return const VaultConfig();
      final json = jsonDecode(f.readAsStringSync());
      if (json is! Map) return const VaultConfig();
      final ms = json['autosave_ms'];
      final z = json['zoom'];
      return VaultConfig(
        autosaveMs: ms is int
            ? ms.clamp(minAutosaveMs, maxAutosaveMs)
            : defaultConfig.autosaveMs,
        zoom: z is num
            ? z.toDouble().clamp(minZoom, maxZoom)
            : defaultConfig.zoom,
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
      const JsonEncoder.withIndent('  ')
          .convert({'autosave_ms': autosaveMs, 'zoom': zoom}),
    );
  }

  VaultConfig copyWith({int? autosaveMs, double? zoom}) => VaultConfig(
        autosaveMs: autosaveMs ?? this.autosaveMs,
        zoom: zoom ?? this.zoom,
      );
}
