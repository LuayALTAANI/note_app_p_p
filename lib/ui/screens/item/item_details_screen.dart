// ui/screens/item/item_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/data/providers.dart';
import 'item_actions.dart';
import 'item_share.dart';
import 'item_rename_dialog.dart';
import 'widgets/main_media_card.dart';
import 'widgets/detail_block_tile.dart';

class ItemDetailsScreen extends ConsumerWidget {
  const ItemDetailsScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    return StreamBuilder<Item?>(
      stream: db.itemsDao.watchById(itemId),
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final title = (item.title ?? '').trim().isEmpty
            ? item.type.toUpperCase()
            : item.title!.trim();

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              // ✅ Rename moved to top
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final t = await showRenameDialog(context, title);
                  if (t == null) return;
                  final v = t.trim();
                  if (v.isEmpty || v == title) return;
                  await db.itemsDao.updateTitle(item.id, v);
                },
              ),

              // ✅ Change source moved to top (works for photo/video/pdf/voice)
              if (item.mainType != 'note')
                IconButton(
                  tooltip: 'Change source',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () => changeMainMedia(context, db, item),
                ),

              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => shareItem(context, db, item),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => deleteItem(context, db, item),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => addDetailBlock(context, db, item),
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<List<DetailBlock>>(
            stream: db.blocksDao.watchBlocksForItem(item.id),
            builder: (context, bSnap) {
              final blocks = [...(bSnap.data ?? [])];

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text('Main'),
                  const SizedBox(height: 8),

                  MainMediaCard(item: item),

                  const SizedBox(height: 24),
                  const Text('Detail blocks'),
                  const SizedBox(height: 8),
                  if (blocks.isEmpty)
                    const Text('No detail blocks')
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final moved = blocks.removeAt(oldIndex);
                        blocks.insert(newIndex, moved);
                        await db.blocksDao.reorderBlocks(
                          item.id,
                          blocks.map((e) => e.id.toString()).toList(),
                        );
                      },
                      children: [
                        for (final b in blocks)
                          DetailBlockTile(
                            key: ValueKey(b.id),
                            block: b,
                          ),
                      ],
                    ),
                  const SizedBox(height: 100),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
