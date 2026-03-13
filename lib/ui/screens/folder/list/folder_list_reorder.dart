import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/app_database.dart';
import '../../../../data/providers.dart';
import '../../../common/folder_color_picker.dart';
import '../../../common/colors.dart';
import '../../../widgets/audio_player_widget.dart';
import '../dialogs/folder_rename_dialog.dart';

class FolderListReorder extends ConsumerStatefulWidget {
  const FolderListReorder({
    super.key,
    required this.folderId,
    required this.query,
  });

  final String folderId;
  final String query;

  @override
  ConsumerState<FolderListReorder> createState() => _FolderListReorderState();
}

class _FolderListReorderState extends ConsumerState<FolderListReorder> {
  bool _match(String q, String s) {
    if (q.isEmpty) return true;
    return s.toLowerCase().contains(q.toLowerCase());
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)} ${d.day}/${d.month}/${d.year}';
  }

  IconData _itemIcon(String type) {
    switch (type) {
      case 'photo':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'voice':
        return Icons.mic;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    final foldersStream = db.foldersDao.watchChildren(widget.folderId, 'free');
    final itemsStream = db.itemsDao.watchItemsInFolder(widget.folderId, 'free');

    return StreamBuilder<List<Folder>>(
      stream: foldersStream,
      builder: (context, fSnap) {
        final foldersRaw = fSnap.data ?? [];
        final folders =
            foldersRaw.where((f) => _match(widget.query, f.name)).toList()
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

        return StreamBuilder<List<Item>>(
          stream: itemsStream,
          builder: (context, iSnap) {
            final itemsRaw = iSnap.data ?? [];
            final items =
                itemsRaw
                    .where((i) => _match(widget.query, i.title ?? i.type))
                    .toList()
                  ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

            return ListView(
              children: [
                if (folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Folders',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: folders.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;

                    final updated = [...folders];
                    final f = updated.removeAt(oldIndex);
                    updated.insert(newIndex, f);

                    await db.foldersDao.reorderFolders(
                      updated.map((e) => e.id).toList(),
                    );
                  },
                  itemBuilder: (context, idx) {
                    final f = folders[idx];
                    return ListTile(
                      key: ValueKey('f-${f.id}'),
                      leading: Icon(Icons.folder, color: Color(f.color)),
                      title: Text(f.name),
                      subtitle: Text(_fmt(f.createdAt)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.color_lens),
                            tooltip: 'Change color',
                            onPressed: () async {
                              final newColor = await showFolderColorPicker(
                                context,
                                currentColor: f.color,
                                presets: folderColorPresets,
                              );
                              if (newColor != null) {
                                await ref
                                    .read(dbProvider)
                                    .foldersDao
                                    .updateColor(f.id, newColor);
                              }
                            },
                          ),
                          if (f.id != 'root')
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Rename',
                              onPressed: () => showRenameFolderDialog(
                                context,
                                ref.read(dbProvider),
                                f,
                              ),
                            ),
                          if (f.id != 'root')
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete folder?'),
                                    content: const Text(
                                      'This will delete the folder and everything inside it.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                await ref
                                    .read(dbProvider)
                                    .foldersDao
                                    .deleteFolderTree(f.id);
                              },
                            ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                      onTap: () => context.push('/folder/${f.id}'),
                    );
                  },
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),

                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;

                    final updated = [...items];
                    final it = updated.removeAt(oldIndex);
                    updated.insert(newIndex, it);

                    await db.itemsDao.reorderItems(
                      widget.folderId,
                      updated.map((e) => e.id).toList(),
                    );
                  },
                  itemBuilder: (context, idx) {
                    final it = items[idx];

                    if (it.type != 'voice') {
                      return ListTile(
                        key: ValueKey('i-${it.id}'),
                        leading: Icon(_itemIcon(it.type)),
                        title: Text(it.title ?? it.type.toUpperCase()),
                        subtitle: Text(_fmt(it.createdAt)),
                        trailing: const Icon(Icons.drag_handle),
                        onTap: () => context.push('/item/${it.id}'),
                      );
                    }

                    return Card(
                      key: ValueKey('i-${it.id}'),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(_itemIcon(it.type)),
                            title: Text(it.title ?? it.type.toUpperCase()),
                            subtitle: Text(_fmt(it.createdAt)),
                            trailing: const Icon(Icons.drag_handle),
                            onTap: () => context.push('/item/${it.id}'),
                          ),
                          FutureBuilder<FileAsset?>(
                            future: db.assetsDao.getById(it.mainData),
                            builder: (context, snap) {
                              final p = snap.data?.path;
                              if (p == null || !File(p).existsSync()) {
                                return const Padding(
                                  padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                                  child: Text('Audio file unavailable'),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  8,
                                ),
                                child: AudioPlayerWidget(
                                  file: File(p),
                                  compact: true,
                                  showTimes: false,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                if (folders.isEmpty && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Empty')),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
