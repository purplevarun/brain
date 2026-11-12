import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import 'models.dart';

/// Local-first vault: a plain folder of .md files and attachments on disk.
/// Everything is relative to [root]; relPaths always use '/'.
class VaultStore {
  VaultStore(this.root);

  final String root;

  String absolute(String relPath) => p.joinAll([root, ...relPath.split('/')]);

  String normalize(String relPath) => p.posix.normalize(relPath);

  /// The directory containing [relPath], as a relPath ('' for root).
  String parentOf(String relPath) {
    final i = relPath.lastIndexOf('/');
    return i < 0 ? '' : relPath.substring(0, i);
  }

  String nameOf(String relPath) => relPath.split('/').last;

  /// Resolves a link target found in a note at [noteRelPath] against the
  /// note's own folder. Returns null if it escapes the vault root.
  String? resolveRel(String noteRelPath, String href) {
    final base = parentOf(noteRelPath);
    final joined = base.isEmpty ? href : '$base/$href';
    final norm = normalize(joined);
    if (norm.startsWith('../') || norm == '..' || p.posix.isAbsolute(norm)) {
      return null;
    }
    return norm;
  }

  Future<VaultNode> tree() => _scanDir(Directory(root), '');

  Future<VaultNode> _scanDir(Directory dir, String rel) async {
    final dirs = <VaultNode>[];
    final files = <VaultNode>[];
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      final childRel = rel.isEmpty ? name : '$rel/$name';
      if (entity is Directory) {
        dirs.add(await _scanDir(entity, childRel));
      } else if (entity is File) {
        files.add(VaultNode(name: name, relPath: childRel, isDir: false));
      }
    }
    int byName(VaultNode a, VaultNode b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    dirs.sort(byName);
    files.sort(byName);
    return VaultNode(
      name: rel.isEmpty ? p.basename(root) : nameOf(rel),
      relPath: rel,
      isDir: true,
      children: [...dirs, ...files],
    );
  }

  /// Emits the tree immediately, then again on every filesystem change.
  Stream<VaultNode> watchTree() async* {
    yield await tree();
    var last = DateTime.now();
    await for (final _ in DirectoryWatcher(root).events) {
      final now = DateTime.now();
      if (now.difference(last) < const Duration(milliseconds: 300)) continue;
      last = now;
      yield await tree();
    }
  }

  /// Depth-first list of every file relPath (for search and quick-open).
  Future<List<String>> listAllFiles([String rel = '']) async {
    final out = <String>[];
    final dir = rel.isEmpty ? Directory(root) : Directory(absolute(rel));
    if (!await dir.exists()) return out;
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      final childRel = rel.isEmpty ? name : '$rel/$name';
      if (entity is Directory) {
        out.addAll(await listAllFiles(childRel));
      } else if (entity is File) {
        out.add(childRel);
      }
    }
    return out;
  }

  Future<String> readNote(String relPath) =>
      File(absolute(relPath)).readAsString();

  Future<void> writeNote(String relPath, String contents) async {
    final f = File(absolute(relPath));
    await f.parent.create(recursive: true);
    await f.writeAsString(contents);
  }

  Future<void> createFolder(String relPath) =>
      Directory(absolute(relPath)).create(recursive: true);

  Future<void> rename(String fromRel, String toRel) async {
    final from = absolute(fromRel);
    final to = absolute(toRel);
    await Directory(p.dirname(to)).create(recursive: true);
    final type = await FileSystemEntity.type(from);
    if (type == FileSystemEntityType.directory) {
      await Directory(from).rename(to);
    } else {
      await File(from).rename(to);
    }
  }

  Future<void> delete(String relPath) async {
    final entity = File(absolute(relPath));
    if (await entity.exists()) {
      await entity.delete();
      return;
    }
    final dir = Directory(absolute(relPath));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Copies an external file into [dirRel] and returns its new relPath.
  /// Picks `name_2.ext`, `name_3.ext`… on collisions.
  Future<String> importFile(String sourcePath, String dirRel) async {
    final src = File(sourcePath);
    var name = p.basename(sourcePath).replaceAll(' ', '_');
    var target = dirRel.isEmpty ? name : '$dirRel/$name';
    var n = 2;
    while (await File(absolute(target)).exists()) {
      final stem = p.basenameWithoutExtension(name);
      final ext = p.extension(name);
      target = dirRel.isEmpty
          ? '${stem}_$n$ext'
          : '$dirRel/${stem}_$n$ext';
      n++;
    }
    final dest = File(absolute(target));
    await dest.parent.create(recursive: true);
    await src.copy(dest.path);
    return target;
  }
}
