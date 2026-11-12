import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import 'brain_theme.dart';

final brainThemeProvider = NotifierProvider<BrainThemeNotifier, BrainTheme>(
  BrainThemeNotifier.new,
);

class BrainThemeNotifier extends Notifier<BrainTheme> {
  static const _key = 'theme_name';

  @override
  BrainTheme build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return brainThemes.firstWhere(
      (t) => t.name == saved,
      orElse: () => githubDark,
    );
  }

  void set(BrainTheme theme) {
    state = theme;
    ref.read(sharedPrefsProvider).setString(_key, theme.name);
  }
}

final materialThemeProvider = Provider<ThemeData>((ref) {
  final t = ref.watch(brainThemeProvider);
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: t.bg,
    colorScheme: ColorScheme.dark(
      primary: t.accent,
      secondary: t.accent,
      surface: t.surface,
      surfaceContainerHighest: t.surfaceAlt,
      error: t.red,
      onPrimary: t.bg,
      onSurface: t.text,
      onSurfaceVariant: t.textDim,
      outline: t.border,
    ),
    dividerColor: t.border,
    iconTheme: IconThemeData(color: t.textDim, size: 18),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.accent,
      selectionColor: t.accent.withValues(alpha: 0.3),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.surface,
      foregroundColor: t.text,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: t.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surfaceAlt,
      textStyle: TextStyle(color: t.text, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: t.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      textStyle: TextStyle(color: t.text, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.surfaceAlt,
      contentTextStyle: TextStyle(color: t.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surfaceAlt,
      hintStyle: TextStyle(color: t.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.accent),
      ),
      isDense: true,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: t.accent,
      unselectedLabelColor: t.textDim,
      indicatorColor: t.accent,
      dividerColor: t.border,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: t.textDim,
      collapsedIconColor: t.textDim,
      textColor: t.text,
      collapsedTextColor: t.text,
    ),
    listTileTheme: ListTileThemeData(
      textColor: t.text,
      iconColor: t.textDim,
      dense: true,
    ),
  );
});
