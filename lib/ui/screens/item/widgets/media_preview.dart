import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/data/providers.dart';
import 'package:note_app_pp/ui/common/video_meta.dart';
import 'package:note_app_pp/ui/screens/local_video_screen.dart';
import 'package:note_app_pp/ui/widgets/audio_player_widget.dart';
import 'package:note_app_pp/ui/widgets/youtube_focused_player.dart';
import 'package:note_app_pp/ui/screens/media_viewer_screen.dart';
import 'preview_widget.dart';

class MediaPreview extends ConsumerWidget {
  const MediaPreview({super.key, required this.item, required this.title});

  final Item item;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    if (item.mainType == 'video' && looksLikeHttpUrl(item.mainData)) {
      return YoutubeFocusedPlayer(youtubeUrl: item.mainData.trim());
    }

    return FutureBuilder<FileAsset?>(
      future: db.assetsDao.getById(item.mainData),
      builder: (context, snap) {
        final path = snap.data?.path;
        if (path == null || !File(path).existsSync()) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No media'),
          );
        }

        if (item.mainType == 'voice') {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: AudioPlayerWidget(file: File(path)),
          );
        }

        if (item.mainType == 'video') {
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    LocalVideoScreen(file: File(path), title: title),
              ),
            ),
            child: SizedBox(
              height: 220,
              child: PreviewWidget(type: 'video', path: path),
            ),
          );
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaViewerScreen(
                  title: title,
                  type: item.mainType,
                  filePath: path,
                ),
              ),
            );
          },
          child: SizedBox(
            height: 220,
            child: PreviewWidget(type: item.mainType, path: path),
          ),
        );
      },
    );
  }
}