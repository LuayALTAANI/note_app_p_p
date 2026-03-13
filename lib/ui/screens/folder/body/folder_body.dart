import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../list/folder_list_normal.dart';
import '../list/folder_list_reorder.dart';

class FolderBody extends ConsumerWidget {
  const FolderBody({
    super.key,
    required this.folderId,
    required this.sortMode,
    required this.query,
    required this.reorderMode,
    required this.searching,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  final String folderId;
  final String sortMode;
  final String query;
  final bool reorderMode;
  final bool searching;
  final TextEditingController searchCtrl;

  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (searching)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                labelText: 'Search in this folder',
              ),
              // ✅ LIVE SEARCH
              onChanged: (_) => onSearchChanged(),
            ),
          ),
        Expanded(
          child: (sortMode == 'free' && reorderMode)
              ? FolderListReorder(folderId: folderId, query: query)
              : FolderListNormal(
                  folderId: folderId,
                  sortMode: sortMode,
                  query: query,
                ),
        ),
      ],
    );
  }
}
