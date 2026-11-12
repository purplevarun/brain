import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/providers.dart';

/// Sidebar tags tab: every frontmatter/inline #tag with its notes.
class TagPanel extends ConsumerWidget {
  const TagPanel({super.key, this.onOpenFile});

  final VoidCallback? onOpenFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BrainTheme theme = ref.watch(brainThemeProvider);
    final tags = ref.watch(tagsProvider);
    final filter = ref.watch(tagFilterProvider);

    return tags.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => Center(child: Text('$e')),
      data: (map) {
        if (map.isEmpty) {
          return Center(
            child: Text(
              'No tags yet.\nUse #tag in notes or frontmatter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textDim, fontSize: 12),
            ),
          );
        }
        final names = map.keys.toList()..sort();
        if (filter == null) {
          return ListView(
            children: [
              for (final name in names)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.sell_outlined,
                    size: 14,
                    color: theme.cyan,
                  ),
                  title: Text(
                    '#$name',
                    style: TextStyle(color: theme.text, fontSize: 12.5),
                  ),
                  trailing: Text(
                    '${map[name]!.length}',
                    style: TextStyle(color: theme.textDim, fontSize: 11),
                  ),
                  onTap: () =>
                      ref.read(tagFilterProvider.notifier).state = name,
                ),
            ],
          );
        }
        final paths = map[filter] ?? const <String>[];
        return Column(
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_back, size: 16),
              title: Text(
                '#$filter',
                style: TextStyle(
                  color: theme.cyan,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => ref.read(tagFilterProvider.notifier).state = null,
            ),
            Divider(height: 1, color: theme.border),
            Expanded(
              child: ListView(
                children: [
                  for (final path in paths)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: theme.textDim,
                      ),
                      title: Text(
                        path,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.text, fontSize: 12),
                      ),
                      onTap: () {
                        ref.read(openPathProvider.notifier).state = path;
                        onOpenFile?.call();
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
