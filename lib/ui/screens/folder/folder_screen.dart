import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/app_database.dart';
import '../../../data/providers.dart';
import 'folder_app_bar.dart';
import 'folder_add_sheet.dart';
import 'body/folder_body.dart';

class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({super.key, required this.folderId});
  final String folderId;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  bool _reorderMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final folderId = widget.folderId;

    return StreamBuilder<Folder?>(
      stream: db.foldersDao.watchById(folderId),
      builder: (context, snap) {
        final f = snap.data;

        if (snap.connectionState != ConnectionState.active && f == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final title = f?.name ?? (folderId == 'root' ? 'Root' : 'Folder');
        final sortMode = f?.sortMode ?? 'name';

        // If user switches away from free sort, exit reorder mode automatically
        if (sortMode != 'free' && _reorderMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _reorderMode = false);
          });
        }

        return Scaffold(
          appBar: FolderAppBar(
            title: title,
            folderId: folderId,
            sortMode: sortMode,
            searching: _searching,
            reorderMode: _reorderMode,
            onToggleSearch: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) _searchCtrl.clear();
              });
            },
            onToggleReorder: () => setState(() => _reorderMode = !_reorderMode),
            onSelectSort: (v) async {
              await db.foldersDao.setSortMode(folderId, v);
              if (v != 'free' && mounted) setState(() => _reorderMode = false);
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showFolderAddSheet(
              context: context,
              db: db,
              folderId: folderId,
            ),
            child: const Icon(Icons.add),
          ),
          body: FolderBody(
            folderId: folderId,
            sortMode: sortMode,
            query: _searchCtrl.text.trim(),
            reorderMode: _reorderMode,
            searching: _searching,
            searchCtrl: _searchCtrl,
            onSearchChanged: () {
              setState(() {});
            },
          ),
        );
      },
    );
  }
}
