// lib/ui/screens/item/widgets/detail_block_tile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/data/providers.dart';
import 'package:note_app_pp/ui/common/confirm_dialog.dart';
import 'package:note_app_pp/ui/common/snackbar.dart';
import 'package:note_app_pp/ui/common/video_meta.dart';
import 'package:note_app_pp/ui/screens/local_video_screen.dart';
import 'package:note_app_pp/ui/screens/youtube_block_viewer_screen.dart';
import 'package:note_app_pp/ui/screens/item/item_share.dart';
import 'package:note_app_pp/ui/widgets/audio_player_widget.dart';
import 'package:note_app_pp/storage/file_manager.dart';

import '../item_block_meta.dart';
import '../item_rename_dialog.dart';
import 'full_screen_note_editor.dart';

class DetailBlockTile extends ConsumerWidget {
  const DetailBlockTile({super.key, required this.block});
  final DetailBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    final isText = block.type == 'text';
    final isVoice = block.type == 'voice';
    final isVideo = block.type == 'video';

    final yt = isVideo ? metaYoutubeUrl(block.meta) : null;
    final isYoutubeBlock = isVideo && block.data.trim().isEmpty && yt != null && tryExtractYoutubeId(yt) != null;
    final isLocalVideoBlock = isVideo && block.data.trim().isNotEmpty;

    final title = blockTitle(block);

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(_detailIcon(block.type)),
            title: Text(title),
            subtitle: isText && block.data.trim().isNotEmpty
                ? Text(block.data, maxLines: 2, overflow: TextOverflow.ellipsis)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.share), onPressed: () => shareBlock(context, db, block)),

                // ✅ YouTube is NOT mixed into local video: link button only for YouTube video blocks.
                if (isYoutubeBlock || (isVideo && block.data.trim().isEmpty))
                  IconButton(
                    tooltip: 'Set / Update YouTube link',
                    icon: const Icon(Icons.link),
                    onPressed: () async {
                      final url = await showRenameDialog(context, yt ?? 'https://youtube.com/watch?v=...');
                      final v = (url ?? '').trim();

                      if (v.isEmpty) {
                        await setBlockYoutubeUrl(db, block, null);
                        showSnack(context, 'YouTube link removed');
                        return;
                      }
                      if (tryExtractYoutubeId(v) == null) {
                        showSnack(context, 'Invalid YouTube link');
                        return;
                      }

                      await setBlockYoutubeUrl(db, block, v);
                      showSnack(context, 'YouTube link saved');
                    },
                  ),

                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final t = await showRenameDialog(context, title);
                    if (t != null) await setBlockTitle(db, block, t);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Delete block?',
                      message: 'Remove this block?',
                    );
                    if (!ok) return;

                    if (block.type != 'text' && block.data.isNotEmpty) {
                      final asset = await db.assetsDao.getById(block.data);
                      if (asset != null) {
                        await FileManager().deleteFileIfExists(asset.path);
                        await db.assetsDao.deleteAsset(asset.id);
                      }
                    }
                    await db.blocksDao.deleteBlock(block.id);
                  },
                ),
              ],
            ),
            onTap: () async {
              if (block.type == 'text') {
                final updated = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => FullScreenNoteEditor(initialText: block.data)),
                );
                if (updated != null) await db.blocksDao.updateText(block.id, updated);
                return;
              }

              if (isVoice) return;

              // ✅ Separate local video flow: always full-screen.
              if (isLocalVideoBlock) {
                final asset = await db.assetsDao.getById(block.data);
                final p = asset?.path;
                if (p == null || !File(p).existsSync()) {
                  showSnack(context, 'Video file not found');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalVideoScreen(file: File(p), title: title),
                  ),
                );
                return;
              }

              // ✅ Separate YouTube flow: open a dedicated viewer screen with actions.
              if (isYoutubeBlock) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => YoutubeBlockViewerScreen(blockId: block.id)),
                );
                return;
              }

              // other media
              if (block.type != 'text' && block.data.isNotEmpty) {
                final asset = await db.assetsDao.getById(block.data);
                if (asset == null || !File(asset.path).existsSync()) return;
              }
            },
          ),
          if (isVoice)
            FutureBuilder<FileAsset?>(
              future: db.assetsDao.getById(block.data),
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
                  child: AudioPlayerWidget(file: File(p), compact: true, showTimes: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

IconData _detailIcon(String type) {
  switch (type) {
    case 'folder':
      return Icons.folder;
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
