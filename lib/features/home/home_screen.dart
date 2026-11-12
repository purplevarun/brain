import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/brain_mark.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/vault_config.dart';
import '../browser/file_tree.dart';
import '../browser/note_actions.dart';
import '../editor/editor_screen.dart';
import '../search/quick_open.dart';
import '../search/search_panel.dart';
import '../settings/settings_sheet.dart';
import '../tags/tag_panel.dart';
import '../vault/vault_picker.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultPath = ref.watch(vaultPathProvider);
    if (vaultPath == null) return const VaultPicker();

    return _Shortcuts(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return wide ? const _WideLayout() : const _NarrowLayout();
        },
      ),
    );
  }
}

/// Global shortcuts, handled at the hardware-keyboard level so they fire
/// everywhere — including while a TextField or menu has focus:
/// Cmd/Ctrl+P (or K) quick open, N new note, Shift+N new folder,
/// Shift+D daily log, E toggle mode, B sidebar, 0 focus sidebar,
/// Shift+0 reset zoom, 1 focus editor, =/+ zoom in, - zoom out,
/// , settings. Saving is autosave-only.
class _Shortcuts extends ConsumerStatefulWidget {
  const _Shortcuts({required this.child});

  final Widget child;

  @override
  ConsumerState<_Shortcuts> createState() => _ShortcutsState();
}

class _ShortcutsState extends ConsumerState<_Shortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool get _modifier {
    final kb = HardwareKeyboard.instance;
    final mac = !kIsWeb && Platform.isMacOS;
    return mac ? kb.isMetaPressed : kb.isControlPressed;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_modifier || !mounted) return false;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyP:
      case LogicalKeyboardKey.keyK:
        showQuickOpen(context, ref);
      case LogicalKeyboardKey.keyE:
        ref.read(editModeProvider.notifier).state =
            !ref.read(editModeProvider);
      case LogicalKeyboardKey.keyN:
        shift
            ? NoteActions.newFolder(context, ref)
            : NoteActions.newNote(context, ref);
      case LogicalKeyboardKey.keyD:
        if (!shift) return false;
        openDailyLog(context, ref);
      case LogicalKeyboardKey.digit0:
      case LogicalKeyboardKey.numpad0:
        if (shift) {
          _setZoom(1.0);
        } else {
          ref.read(sidebarCollapsedProvider.notifier).state = false;
          ref.read(sidebarFocusProvider).requestFocus();
        }
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.numpadAdd:
        _bumpZoom(1);
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        _bumpZoom(-1);
      case LogicalKeyboardKey.digit1:
        ref.read(editModeProvider.notifier).state = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(editorFocusProvider).requestFocus();
        });
      case LogicalKeyboardKey.keyB:
        ref.read(sidebarCollapsedProvider.notifier).state =
            !ref.read(sidebarCollapsedProvider);
      case LogicalKeyboardKey.comma:
        showSettings(context);
      default:
        return false;
    }
    return true;
  }

  void _bumpZoom(int dir) {
    final cfg = ref.read(vaultConfigProvider);
    // Round to one decimal so repeated presses don't drift (0.1-step ladder).
    final next = ((cfg.zoom + dir * VaultConfig.zoomStep) * 10).round() / 10;
    _setZoom(next);
  }

  void _setZoom(double zoom) {
    final cfg = ref.read(vaultConfigProvider);
    ref
        .read(vaultConfigProvider.notifier)
        .update(cfg.copyWith(zoom: zoom.clamp(VaultConfig.minZoom, VaultConfig.maxZoom)));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(autofocus: true, child: widget.child);
  }
}

class _WideLayout extends ConsumerWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: collapsed ? 0 : 280,
            child: collapsed
                ? const SizedBox.shrink()
                : const VaultSidebar(),
          ),
          if (!collapsed) VerticalDivider(width: 1, color: theme.border),
          const Expanded(child: EditorScreen()),
        ],
      ),
      floatingActionButton: collapsed
          ? FloatingActionButton.small(
              onPressed: () =>
                  ref.read(sidebarCollapsedProvider.notifier).state = false,
              child: const Icon(Icons.chevron_right),
            )
          : null,
    );
  }
}

class _NarrowLayout extends ConsumerWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    final openPath = ref.watch(openPathProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          openPath?.split('/').last ?? 'brain',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, size: 20),
            tooltip: 'Quick open',
            onPressed: () => showQuickOpen(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => showSettings(context),
          ),
        ],
      ),
      drawer: const Drawer(width: 300, child: VaultSidebar()),
      body: const EditorScreen(),
      backgroundColor: theme.bg,
    );
  }
}

/// Left panel: brand + actions + Files/Search/Tags tabs.
class VaultSidebar extends ConsumerWidget {
  const VaultSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    final vaultPath = ref.watch(vaultPathProvider) ?? '';
    final vaultName = vaultPath.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'vault';

    void closeDrawerIfAny() {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold?.isDrawerOpen == true) Navigator.of(context).pop();
    }

    return Material(
      color: theme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
              child: Row(
                children: [
                  BrainMark(size: 20, color: theme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: vaultPath,
                      child: Text(
                        vaultName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _Action(
                    icon: Icons.edit_calendar_outlined,
                    tooltip: 'Daily log (Ctrl/Cmd+Shift+N)',
                    onTap: () => openDailyLog(context, ref),
                  ),
                  _Action(
                    icon: Icons.note_add_outlined,
                    tooltip: 'New note (Ctrl/Cmd+N)',
                    onTap: () => NoteActions.newNote(context, ref),
                  ),
                  _Action(
                    icon: Icons.create_new_folder_outlined,
                    tooltip: 'New folder',
                    onTap: () => NoteActions.newFolder(context, ref),
                  ),
                  _Action(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onTap: () => showSettings(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.border),
            Expanded(
              child: Focus(
                focusNode: ref.watch(sidebarFocusProvider),
                child: _SidebarSections(onOpenFile: closeDrawerIfAny),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// VS Code-style sidebar body: vertically stacked collapsible sections.
/// Daily Notes and Notes are expanded by default and split the space;
/// Search and Tags are collapsed headers that open on click ("stay down").
class _SidebarSections extends ConsumerStatefulWidget {
  const _SidebarSections({required this.onOpenFile});

  final VoidCallback onOpenFile;

  @override
  ConsumerState<_SidebarSections> createState() => _SidebarSectionsState();
}

class _SidebarSectionsState extends ConsumerState<_SidebarSections> {
  final _open = <String>{'daily', 'notes'};

  void _toggle(String key) => setState(
      () => _open.contains(key) ? _open.remove(key) : _open.add(key));

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(brainThemeProvider);
    final tree = ref.watch(treeProvider);
    final (daily, notes) = switch (tree) {
      AsyncData(:final value) when value != null => splitDailyNotes(value),
      _ => (const <VaultNode>[], const <VaultNode>[]),
    };

    Widget fileBody(List<VaultNode> nodes, String hint) {
      if (tree.isLoading) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      if (tree.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Cannot read vault.',
              style: TextStyle(color: theme.textDim, fontSize: 11.5),
            ),
          ),
        );
      }
      return TreeNodes(
        nodes: nodes,
        emptyHint: hint,
        onOpenFile: widget.onOpenFile,
      );
    }

    return Column(
      children: [
        _section(
          'daily',
          'Daily Notes',
          fileBody(
            daily,
            'No daily logs yet —\nCtrl/Cmd+Shift+D creates today\'s.',
          ),
        ),
        _section(
          'notes',
          'Notes',
          fileBody(notes, 'No notes yet —\nCtrl/Cmd+N creates one.'),
        ),
        _section('search', 'Search',
            SearchPanel(onOpenFile: widget.onOpenFile)),
        _section('tags', 'Tags', TagPanel(onOpenFile: widget.onOpenFile)),
      ],
    );
  }

  Widget _section(String key, String title, Widget child) {
    final open = _open.contains(key);
    final header =
        _SectionHeader(title: title, open: open, onToggle: () => _toggle(key));
    if (!open) return header;
    return Expanded(
      child: Column(children: [header, Expanded(child: child)]),
    );
  }
}

/// Tappable collapsible section header — chevron + uppercase label + rule.
class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({
    required this.title,
    required this.open,
    required this.onToggle,
  });

  final String title;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(brainThemeProvider);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: theme.textDim,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textDim,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17),
        ),
      ),
    );
  }
}
