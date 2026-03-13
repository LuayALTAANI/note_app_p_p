import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({
    super.key,
    required this.file,
    required this.title,
  });

  final File file;
  final String title;

  @override
  State<LocalVideoScreen> createState() => _LocalVideoScreenState();
}

class _LocalVideoScreenState extends State<LocalVideoScreen> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.file(widget.file);
    await c.initialize();
    await c.play();
    setState(() => _c = c);
  }

  @override
  void dispose() {
    final c = _c;
    _c = null;
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      body: SafeArea(
        child: c == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(c, allowScrubbing: true),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                c.value.isPlaying ? c.pause() : c.play();
                              }),
                              icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            ),
                            Text(_fmt(c.value.position),),
                            const Spacer(),
                            Text(_fmt(c.value.duration),),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
