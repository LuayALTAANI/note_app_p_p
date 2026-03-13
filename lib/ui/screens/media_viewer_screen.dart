import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/audio_player_widget.dart';
import '../widgets/pdf_viewer_widget.dart';
import '../widgets/photo_viewer_widget.dart';
import '../widgets/video_player_widget.dart';
import '../common/video_meta.dart';

class MediaViewerScreen extends StatelessWidget {
  const MediaViewerScreen({
    super.key,
    required this.title,
    required this.type,
    this.noteText,
    this.filePath,
    this.youtubeUrl,
  });

  final String title;
  final String type;
  final String? noteText;
  final String? filePath;

  final String? youtubeUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: _SafeViewer(
          builder: () => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (type == 'note') {
      final t = (noteText ?? '').trim();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(t.isEmpty ? '(Empty note)' : t),
      );
    }

    if (type == 'video') {
      final local = (filePath ?? '').trim();
      final yt = (youtubeUrl ?? '').trim();

      final hasLocal = local.isNotEmpty && File(local).existsSync();
      final hasYt = yt.isNotEmpty && tryExtractYoutubeId(yt) != null;

      if (!hasLocal && !hasYt) return const Center(child: Text('No video source'));

      return Padding(
        padding: const EdgeInsets.all(12),
        child: VideoPlayerWidget(
          localFile: hasLocal ? File(local) : null,
          youtubeUrl: hasYt ? yt : null,
        ),
      );
    }

    final p = (filePath ?? '').trim();
    if (p.isEmpty) return const Center(child: Text('No file'));

    final f = File(p);
    if (!f.existsSync()) return const Center(child: Text('File unavailable'));

    switch (type) {
      case 'photo':
        return PhotoViewerWidget(file: f);
      case 'voice':
        return Padding(
          padding: const EdgeInsets.all(16),
          child: AudioPlayerWidget(file: f),
        );
      case 'pdf':
        return PdfViewerWidget(file: f);
      default:
        return const Center(child: Text('Unsupported'));
    }
  }
}

class _SafeViewer extends StatelessWidget {
  const _SafeViewer({required this.builder});
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    try {
      return builder();
    } catch (_) {
      return const Center(child: Text('Failed to open this media.'));
    }
  }
}