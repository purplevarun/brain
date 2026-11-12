import 'dart:io';

import 'package:brain/core/providers.dart';
import 'package:brain/features/vault/backup.dart';
import 'package:brain/main.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end coverage at the widget seam: real BrainApp, real filesystem,
/// only the OS file dialogs faked out. This is the layer that proved the
/// "all three vault buttons do nothing" bug on macOS (missing
/// `files.user-selected` entitlement → silent PlatformException), so the
/// picker-error test below is the regression test for it.
///
/// NOTE: once a vault is open, `DirectoryWatcher` on macOS is a polling
/// watcher (Timer.periodic) — `pumpAndSettle` can never finish, so after a
/// vault opens we use `runAsync` (lets real file IO complete) + fixed pumps.
void main() {
  late Directory tmp;
  late SharedPreferences prefs;
  late FakeFilePicker fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('brain_e2e');
    fake = FakeFilePicker();
    FilePickerPlatform.instance = fake;
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, {bool withVault = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const BrainApp(),
      ),
    );
    if (withVault) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    } else {
      await tester.pumpAndSettle();
    }
  }

  /// Tap inside `runAsync` so the whole handler chain — fake dialogs AND
  /// real file IO — completes on the real event loop, then rebuild. Use
  /// instead of pumpAndSettle once a vault might be open.
  Future<void> tapAndFlush(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('picker screen shows all vault actions', (tester) async {
    await pumpApp(tester);
    expect(find.text('Open a vault folder'), findsOneWidget);
    expect(find.text('Create a new vault'), findsOneWidget);
    expect(
      find.text('Import vault backup (.purplebrain)'),
      findsOneWidget,
    );
  });

  testWidgets('open a vault folder → vault browser', (tester) async {
    final vault = Directory(p.join(tmp.path, 'picked_vault'))..createSync();
    fake.directoryResult = vault.path;

    await pumpApp(tester);
    await tapAndFlush(tester, find.text('Open a vault folder'));

    expect(fake.directoryCalls, 1);
    expect(prefs.getString('vault_path'), vault.path);
    expect(find.text('picked_vault'), findsOneWidget);
    expect(find.text('Open a vault folder'), findsNothing);
  });

  testWidgets('create a new vault → brain_vault dir + opens it', (
    tester,
  ) async {
    fake.directoryResult = tmp.path;

    await pumpApp(tester);
    await tapAndFlush(tester, find.text('Create a new vault'));

    final created = Directory(p.join(tmp.path, 'brain_vault'));
    expect(created.existsSync(), isTrue);
    expect(File(p.join(created.path, 'README.md')).existsSync(), isTrue);
    expect(prefs.getString('vault_path'), created.path);
    expect(find.text('brain_vault'), findsOneWidget);
  });

  testWidgets('picker errors surface as snackbars, not silent dead buttons', (
    tester,
  ) async {
    // Exact failure the macOS app hit before the entitlement fix.
    fake.error = PlatformException(
      code: 'ENTITLEMENT_NOT_FOUND',
      message: 'Either the Read-Only or Read-Write entitlement is required.',
    );

    await pumpApp(tester);
    await tapAndFlush(tester, find.text('Open a vault folder'));

    expect(find.textContaining('Could not open folder'), findsOneWidget);
    expect(prefs.getString('vault_path'), isNull);
  });

  testWidgets('import .purplebrain → extracts files + opens vault', (
    tester,
  ) async {
    final src = Directory(p.join(tmp.path, 'src_vault'))..createSync();
    File(p.join(src.path, 'note.md')).writeAsStringSync('# hello');
    final backupFile = File(p.join(tmp.path, 'backup.purplebrain'));
    // Real IO must run on the real event loop — the test body is fake-async.
    await tester.runAsync(() async {
      await backupFile.writeAsBytes(await buildVaultArchive(src.path));
    });
    fake.pickResult = [_DiskPlatformFile(backupFile.path)];
    final extractTarget = Directory(p.join(tmp.path, 'restored_vault'))
      ..createSync();
    fake.directoryResult = extractTarget.path;

    await pumpApp(tester);
    await tapAndFlush(tester, find.text('Import vault backup (.purplebrain)'));

    expect(
      File(p.join(extractTarget.path, 'note.md')).readAsStringSync(),
      '# hello',
    );
    expect(prefs.getString('vault_path'), extractTarget.path);
    expect(find.text('restored_vault'), findsOneWidget);
    expect(find.textContaining('Vault imported'), findsOneWidget);
  });

  testWidgets('export → writes a real .purplebrain zip archive', (
    tester,
  ) async {
    final vault = Directory(p.join(tmp.path, 'my_vault'))..createSync();
    File(p.join(vault.path, 'day.md')).writeAsStringSync('## work');
    SharedPreferences.setMockInitialValues({'vault_path': vault.path});
    prefs = await SharedPreferences.getInstance();
    fake.saveDir = tmp;

    await pumpApp(tester, withVault: true);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Export backup'));
    await tester.pump(const Duration(milliseconds: 300));
    await tapAndFlush(tester, find.text('Export backup'));

    expect(fake.savedNames, hasLength(1));
    expect(fake.savedNames.single, endsWith('.purplebrain'));
    final exported = File(p.join(tmp.path, fake.savedNames.single));
    expect(exported.existsSync(), isTrue);
    // Payload is a standard zip — roundtrip it to prove contents.
    final restoreDir = Directory(p.join(tmp.path, 'restore_dst'))
      ..createSync();
    await tester.runAsync(() async {
      await extractVaultArchive(
        await exported.readAsBytes(),
        restoreDir.path,
      );
    });
    expect(
      File(p.join(restoreDir.path, 'day.md')).readAsStringSync(),
      '## work',
    );
  });

  test('purplebrain archive roundtrip: contents preserved, dotfiles skipped', () async {
    final src = Directory(p.join(tmp.path, 'plain_src'))..createSync();
    File(p.join(src.path, 'a.md')).writeAsStringSync('alpha');
    File(p.join(src.path, '.hidden')).writeAsStringSync('secret');
    final nested = Directory(p.join(src.path, 'sub'))..createSync();
    File(p.join(nested.path, 'b.md')).writeAsStringSync('beta');

    final bytes = await buildVaultArchive(src.path);
    expect(Uint8List.fromList(bytes.sublist(0, 2)), [0x50, 0x4B]); // 'PK'

    final dst = Directory(p.join(tmp.path, 'plain_dst'))..createSync();
    final count = await extractVaultArchive(bytes, dst.path);
    expect(count, 2);
    expect(File(p.join(dst.path, 'a.md')).readAsStringSync(), 'alpha');
    expect(File(p.join(dst.path, 'sub', 'b.md')).readAsStringSync(), 'beta');
    expect(File(p.join(dst.path, '.hidden')).existsSync(), isFalse);
  });
}

/// File dialogs return canned answers; every call is recorded so tests can
/// assert which dialog the UI actually tried to open.
final class FakeFilePicker extends FilePickerPlatform {
  String? directoryResult;
  List<PlatformFile> pickResult = [];
  Directory? saveDir;
  Object? error;
  int directoryCalls = 0;
  final savedNames = <String>[];

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    directoryCalls++;
    if (error != null) throw error!;
    return directoryResult;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (error != null) throw error!;
    return pickResult;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (error != null) throw error!;
    savedNames.add(fileName);
    if (saveDir == null) return null;
    final f = File(p.join(saveDir!.path, fileName));
    await f.writeAsBytes(bytes);
    return f.uri;
  }
}

/// A picked file backed by a real path on disk (how the native picker
/// reports results on desktop).
final class _DiskPlatformFile extends PlatformFile {
  _DiskPlatformFile(this._path);
  final String _path;

  @override
  String get name => p.basename(_path);

  @override
  Uri get uri => Uri.file(_path);

  @override
  XFile get xFile => XFile(_path);

  @override
  int? lengthSync() => File(_path).lengthSync();

  @override
  Future<int?> length() async => File(_path).length();

  @override
  Future<Uint8List> readAsBytes() => File(_path).readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      File(_path).openRead().map(Uint8List.fromList);
}
