import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

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
