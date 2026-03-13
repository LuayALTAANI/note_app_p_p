// lib/ui/widgets/video_player_widget.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../common/video_meta.dart';
import 'youtube_inline_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.localFile,
    required this.youtubeUrl,
  });

  final File? localFile;
  final String? youtubeUrl;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _local;
  bool _localReady = false;

  bool get _hasLocal =>
      widget.localFile != null && widget.localFile!.existsSync();

  bool get _hasYt =>
      widget.youtubeUrl != null &&
      tryExtractYoutubeId(widget.youtubeUrl!) != null;

  @override
  void initState() {
    super.initState();
    _initLocalIfNeeded();
  }

  Future<void> _initLocalIfNeeded() async {
    if (!_hasLocal) return;
    _local ??= VideoPlayerController.file(widget.localFile!);
    if (!_local!.value.isInitialized) await _local!.initialize();
    _localReady = true;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final localChanged = oldWidget.localFile?.path != widget.localFile?.path;
    if (localChanged) {
      _disposeLocal();
      _localReady = false;
      _initLocalIfNeeded();
    }
  }

  void _disposeLocal() {
    final c = _local;
    _local = null;
    c?.dispose();
  }

  @override
  void dispose() {
    _disposeLocal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasYt && !_hasLocal) {
      return YoutubeInlinePlayer(youtubeUrl: widget.youtubeUrl!.trim());
    }
    if (_hasLocal && !_hasYt) return _buildLocal(context);
    if (_hasYt) return YoutubeInlinePlayer(youtubeUrl: widget.youtubeUrl!.trim());
    if (_hasLocal) return _buildLocal(context);
    return const Center(child: Text('No video source'));
  }

  Widget _buildLocal(BuildContext context) {
    if (!_hasLocal) return const Center(child: Text('Offline video unavailable'));
    if (!_localReady || _local == null || !_local!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final c = _local!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VideoPlayer(c),
          ),
        ),
        VideoProgressIndicator(c, allowScrubbing: true),
        Row(
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => c.value.isPlaying ? c.pause() : c.play()),
              icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Text(_fmt(c.value.position)),
            const Spacer(),
            Text(_fmt(c.value.duration)),
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
