import 'package:brain/core/providers.dart';
import 'package:brain/core/vault_config.dart';
import 'package:brain/core/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _ZoomedConfig extends VaultConfigNotifier {
  _ZoomedConfig(this._config);

  final VaultConfig _config;

  @override
  VaultConfig build() => _config;
}

/// The window imposes tight full-size constraints; without OverflowBox the
/// child would clamp to full size and Transform.scale would crop instead of
/// magnify. These tests pin the geometry so that bug can't come back.
void main() {
  const marker = Key('content');

  Widget app(double zoom) => ProviderScope(
        overrides: [
          vaultConfigProvider
              .overrideWith(() => _ZoomedConfig(VaultConfig(zoom: zoom))),
        ],
        child: MaterialApp(
          builder: (ctx, child) => WindowZoom(child: child!),
          home: const SizedBox.expand(key: marker),
        ),
      );

  testWidgets('zoom 1.5 lays the app out at size/1.5 (no clamp/crop)',
      (tester) async {
    await tester.pumpWidget(app(1.5));
    await tester.pump();
    // Test surface is 800x600 -> logical viewport must be 533.3x400.
    final size = tester.getSize(find.byKey(marker));
    expect(size.width, closeTo(800 / 1.5, 0.1));
    expect(size.height, closeTo(600 / 1.5, 0.1));
    // ...and the scaled MediaQuery inside reports the same logical size.
    final ctx = tester.element(find.byKey(marker));
    expect(MediaQuery.sizeOf(ctx).width, closeTo(800 / 1.5, 0.1));
  });

  testWidgets('zoom 0.8 lays the app out larger than the window', (tester) async {
    await tester.pumpWidget(app(0.8));
    await tester.pump();
    final size = tester.getSize(find.byKey(marker));
    expect(size.width, closeTo(800 / 0.8, 0.1));
    expect(size.height, closeTo(600 / 0.8, 0.1));
  });

  testWidgets('zoom 1.0 passes through untouched', (tester) async {
    await tester.pumpWidget(app(1.0));
    await tester.pump();
    expect(tester.getSize(find.byKey(marker)), const Size(800, 600));
    expect(find.byType(OverflowBox), findsNothing);
  });
}
