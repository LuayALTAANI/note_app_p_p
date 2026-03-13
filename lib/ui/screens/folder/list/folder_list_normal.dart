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

class FolderListNormal extends ConsumerWidget {
  const FolderListNormal({
    super.key,
    required this.folderId,
    required this.sortMode,
    required this.query,
  });

  final String folderId;
  final String sortMode;
  final String query;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    final foldersStream = db.foldersDao.watchChildren(folderId, sortMode);
    final itemsStream = db.itemsDao.watchItemsInFolder(folderId, sortMode);

    return StreamBuilder<List<Folder>>(
      stream: foldersStream,
      builder: (context, fSnap) {
        final foldersRaw = fSnap.data ?? [];
        final folders = foldersRaw.where((f) => _match(query, f.name)).toList();

        return StreamBuilder<List<Item>>(
          stream: itemsStream,
          builder: (context, iSnap) {
            final itemsRaw = iSnap.data ?? [];
            final items = itemsRaw
                .where((i) => _match(query, i.title ?? i.type))
                .toList();

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
                ...folders.map(
                  (f) => ListTile(
                    leading: Icon(Icons.folder, color: Color(f.color)),
                    title: Text(f.name),
                    subtitle: Text(_fmt(f.createdAt)),
                    trailing: f.id == 'root'
                        ? null
                        : Row(
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
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Rename',
                                onPressed: () =>
                                    showRenameFolderDialog(context, db, f),
                              ),
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
                            ],
                          ),
                    onTap: () => context.push('/folder/${f.id}'),
                  ),
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),

                ...items.map((i) {
                  if (i.type != 'voice') {
                    return ListTile(
                      leading: Icon(_itemIcon(i.type)),
                      title: Text(i.title ?? i.type.toUpperCase()),
                      subtitle: Text(_fmt(i.createdAt)),
                      onTap: () => context.push('/item/${i.id}'),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(_itemIcon(i.type)),
                          title: Text(i.title ?? i.type.toUpperCase()),
                          subtitle: Text(_fmt(i.createdAt)),
                          onTap: () => context.push('/item/${i.id}'),
                        ),
                        FutureBuilder<FileAsset?>(
                          future: db.assetsDao.getById(i.mainData),
                          builder: (context, snap) {
                            final p = snap.data?.path;
                            if (p == null || !File(p).existsSync()) {
                              return const Padding(
                                padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                                child: Text('Audio file unavailable'),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                }),

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
