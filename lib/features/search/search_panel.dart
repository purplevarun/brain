import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/providers.dart';

/// Sidebar search tab: a field plus matching lines from every .md file.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key, this.onOpenFile});

  final VoidCallback? onOpenFile;

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BrainTheme theme = ref.watch(brainThemeProvider);
    final results = ref.watch(searchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: TextField(
            controller: _controller,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search notes…',
              prefixIcon: Icon(Icons.search, size: 16, color: theme.textDim),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                ref.read(searchQueryProvider.notifier).state = v;
              });
            },
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Center(child: Text('$e')),
            data: (hits) {
              final q = ref.watch(searchQueryProvider);
              if (q.trim().isEmpty) {
                return Center(
                  child: Text(
                    'Type to search all notes.',
                    style: TextStyle(color: theme.textDim, fontSize: 12),
                  ),
                );
              }
              if (hits.isEmpty) {
                return Center(
                  child: Text(
                    'No matches.',
                    style: TextStyle(color: theme.textDim, fontSize: 12),
                  ),
                );
              }
              return ListView.builder(
                itemCount: hits.length,
                itemBuilder: (ctx, i) {
                  final h = hits[i];
                  return InkWell(
                    onTap: () {
                      ref.read(openPathProvider.notifier).state = h.path;
                      widget.onOpenFile?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${h.path}:${h.line}',
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            h.snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textDim,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
