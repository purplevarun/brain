import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Opens a vault file with the OS default app (videos, html, pdfs…).
Future<bool> openFileExternally(String absolutePath) async {
  final uri = Uri.file(absolutePath);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Reveals a file in Finder / Explorer / file manager.
Future<void> revealInFileManager(String absolutePath) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', absolutePath]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', absolutePath]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [File(absolutePath).parent.path]);
  }
}

Future<bool> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
