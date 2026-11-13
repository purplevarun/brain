import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers.dart';

/// Whole-window zoom (VS Code/Electron style): the subtree lays out at
/// size/zoom then scales up, so text AND chrome scale uniformly — dialogs,
/// sheets and tooltips included, since they live in the Navigator overlay.
/// OverflowBox is required: the window imposes tight constraints, so a
/// plain SizedBox would clamp to full size and the scale would just crop.
/// MediaQuery.size is scaled to match so overlays position correctly.
class WindowZoom extends ConsumerWidget {
  const WindowZoom({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(vaultConfigProvider).zoom;
    if (zoom == 1.0) return child;
    final mq = MediaQuery.of(context);
    final logical = Size(mq.size.width / zoom, mq.size.height / zoom);
    return MediaQuery(
      data: mq.copyWith(size: logical),
      child: Transform.scale(
        scale: zoom,
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: child,
        ),
      ),
    );
  }
}

/// Pops the enclosing modal route (dialog, bottom sheet) when Escape is
/// pressed. Key events bubble to this ancestor when no descendant handles
/// them, so TextFields inside still get first shot at keys.
class EscapePop extends StatelessWidget {
  const EscapePop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
