import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/brain_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/models.dart';
import '../../core/platform_utils.dart';
import '../../core/providers.dart';
import 'note_actions.dart';

/// Recursive vault file tree — dirs first, sorted by name (yyyymmdd_
/// prefixes sort chronologically, matching the work-log convention).
class FileTree extends ConsumerWidget {
  const FileTree({super.key, this.onOpenFile});

  final VoidCallback? onOpenFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    final tree = ref.watch(treeProvider);
    final openPath = ref.watch(openPathProvider);

    return tree.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Cannot read vault:\n$e',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textDim, fontSize: 12),
          ),
        ),
      ),
      data: (root) {
        if (root == null || root.children.isEmpty) {
          return Center(
            child: Text(
              'Empty vault — create a note\nto get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textDim, fontSize: 12.5),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (final node in root.children)
              _TreeRow(
                node: node,
                depth: 0,
                openPath: openPath,
                theme: theme,
                onOpenFile: onOpenFile,
              ),
          ],
        );
      },
    );
  }
}

class _TreeRow extends ConsumerStatefulWidget {
  const _TreeRow({
    required this.node,
    required this.depth,
    required this.openPath,
    required this.theme,
    this.onOpenFile,
  });

  final VaultNode node;
  final int depth;
  final String? openPath;
  final BrainTheme theme;
  final VoidCallback? onOpenFile;

  @override
  ConsumerState<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends ConsumerState<_TreeRow> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final theme = widget.theme;
    final selected = widget.openPath == node.relPath;

    if (node.isDir) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            depth: widget.depth,
            selected: false,
            theme: theme,
            onTap: () => setState(() => _expanded = !_expanded),
            onMenu: (pos) => _showMenu(context, pos, node),
            leading: Icon(
              _expanded ? Icons.expand_more : Icons.chevron_right,
              size: 16,
              color: theme.textDim,
            ),
            icon: Icon(
              _expanded ? Icons.folder_open : Icons.folder_outlined,
              size: 15,
              color: theme.accent.withValues(alpha: 0.8),
            ),
            label: node.name,
          ),
          if (_expanded)
            for (final child in node.children)
              _TreeRow(
                node: child,
                depth: widget.depth + 1,
                openPath: widget.openPath,
                theme: theme,
                onOpenFile: widget.onOpenFile,
              ),
        ],
      );
    }

    return _Row(
      depth: widget.depth,
      selected: selected,
      theme: theme,
      onTap: () {
        ref.read(openPathProvider.notifier).state = node.relPath;
        widget.onOpenFile?.call();
      },
      onMenu: (pos) => _showMenu(context, pos, node),
      icon: Icon(_fileIcon(node), size: 15, color: _fileColor(node, theme)),
      label: node.name,
      dimmed: !node.isMarkdown,
    );
  }

  IconData _fileIcon(VaultNode n) => switch (n.extension) {
    'md' => Icons.description_outlined,
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' || 'svg' =>
      Icons.image_outlined,
    'mp4' || 'mov' || 'webm' || 'mkv' || 'avi' || 'm4v' =>
      Icons.videocam_outlined,
    'html' || 'htm' => Icons.code,
    'pdf' => Icons.picture_as_pdf_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  Color _fileColor(VaultNode n, BrainTheme t) => switch (n.extension) {
    'md' => t.textDim,
    'mp4' || 'mov' || 'webm' || 'mkv' || 'avi' || 'm4v' => t.purple,
    'html' || 'htm' => t.cyan,
    _ => t.textDim,
  };

  void _showMenu(BuildContext context, Offset pos, VaultNode node) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final store = ref.read(vaultStoreProvider);
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        pos & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (node.isDir) ...[
          const PopupMenuItem(value: 'note', child: Text('New note here')),
          const PopupMenuItem(value: 'folder', child: Text('New folder')),
        ],
        if (!node.isDir && isDesktop)
          const PopupMenuItem(value: 'reveal', child: Text('Reveal')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete'),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (value) {
      case 'note':
        NoteActions.newNote(context, ref, dirRel: node.relPath);
      case 'folder':
        NoteActions.newFolder(context, ref, dirRel: node.relPath);
      case 'reveal':
        if (store != null) revealInFileManager(store.absolute(node.relPath));
      case 'rename':
        NoteActions.rename(context, ref, node.relPath, node.isDir);
      case 'delete':
        NoteActions.delete(context, ref, node.relPath);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.depth,
    required this.selected,
    required this.theme,
    required this.onTap,
    required this.onMenu,
    required this.icon,
    required this.label,
    this.leading,
    this.dimmed = false,
  });

  final int depth;
  final bool selected;
  final BrainTheme theme;
  final VoidCallback onTap;
  final void Function(Offset pos) onMenu;
  final Widget icon;
  final String label;
  final Widget? leading;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (d) => onMenu(d.globalPosition),
      onLongPressStart: (d) => onMenu(d.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          child: Container(
            color: selected ? theme.accent.withValues(alpha: 0.12) : null,
            padding: EdgeInsets.only(
              left: 8 + depth * 14.0,
              right: 8,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                ?leading,
                icon,
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected
                          ? theme.accent
                          : dimmed
                              ? theme.textDim
                              : theme.text,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
