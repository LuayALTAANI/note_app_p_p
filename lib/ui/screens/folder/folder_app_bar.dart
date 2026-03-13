import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FolderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FolderAppBar({
    super.key,
    required this.title,
    required this.folderId,
    required this.sortMode,
    required this.searching,
    required this.reorderMode,
    required this.onToggleSearch,
    required this.onToggleReorder,
    required this.onSelectSort,
  });

  final String title;
  final String folderId;
  final String sortMode;
  final bool searching;
  final bool reorderMode;

  final VoidCallback onToggleSearch;
  final VoidCallback onToggleReorder;
  final Future<void> Function(String) onSelectSort;

  @override
  Widget build(BuildContext context) {
    final showReorderBtn = sortMode == 'free';

    return AppBar(
      title: Text(title),
      actions: [
        if (showReorderBtn)
          IconButton(
            tooltip: reorderMode ? 'Done' : 'Reorder',
            icon: Icon(reorderMode ? Icons.check : Icons.swap_vert),
            onPressed: onToggleReorder,
          ),
        IconButton(
          tooltip: 'Search',
          icon: Icon(searching ? Icons.close : Icons.search),
          onPressed: onToggleSearch,
        ),
        PopupMenuButton<String>(
          tooltip: 'Sort',
          onSelected: onSelectSort,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'name',
              checked: sortMode == 'name',
              child: const Text('Name (A-Z)'),
            ),
            CheckedPopupMenuItem(
              value: 'date',
              checked: sortMode == 'date',
              child: const Text('Created (newest)'),
            ),
            CheckedPopupMenuItem(
              value: 'free',
              checked: sortMode == 'free',
              child: const Text('Free sort'),
            ),
          ],
        ),

        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
