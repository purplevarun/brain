// window_manager 0.7 moved its API to Flutter's experimental multi-window
// controllers; the 0.5.x bridge API is still maintained and much simpler.
// ignore_for_file: deprecated_member_use
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/legacy.dart';

import 'app/theme/theme_controller.dart';
import 'core/platform_utils.dart';
import 'core/providers.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1200, 780),
      minimumSize: Size(760, 480),
      title: 'brain',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const BrainApp(),
    ),
  );
}

class BrainApp extends ConsumerWidget {
  const BrainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(materialThemeProvider);
    return MaterialApp(
      title: 'brain',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      builder: (context, child) => _WindowZoom(child: child!),
      home: const HomeScreen(),
    );
  }
}

/// Whole-window zoom (VS Code/Electron style): the subtree lays out at
/// size/zoom then scales up, so text AND chrome scale uniformly — dialogs,
/// sheets and tooltips included, since they live in the Navigator overlay.
class _WindowZoom extends ConsumerWidget {
  const _WindowZoom({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(vaultConfigProvider).zoom;
    if (zoom == 1.0) return child;
    return LayoutBuilder(
      builder: (context, c) => Transform.scale(
        scale: zoom,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: c.maxWidth / zoom,
          height: c.maxHeight / zoom,
          child: child,
        ),
      ),
    );
  }
}
