// lib/ui/widgets/youtube_inline_player.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../common/video_meta.dart';

class YoutubeInlinePlayer extends StatefulWidget {
  const YoutubeInlinePlayer({
    super.key,
    required this.youtubeUrl,
    this.borderRadius = 12,
    this.showEmbedHint = true,
  });

  final String youtubeUrl;
  final double borderRadius;
  final bool showEmbedHint;

  @override
  State<YoutubeInlinePlayer> createState() => _YoutubeInlinePlayerState();
}

class _YoutubeInlinePlayerState extends State<YoutubeInlinePlayer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final id = tryExtractYoutubeId(widget.youtubeUrl);
    if (id == null) return;

    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        controlsVisibleAtStart: true,
        enableCaption: true,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant YoutubeInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeUrl.trim() != widget.youtubeUrl.trim()) {
      _controller?.dispose();
      _controller = null;
      _init();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    if (kIsWeb) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreen() async {
    if (kIsWeb) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final id = tryExtractYoutubeId(widget.youtubeUrl);
    if (id == null) {
      return _wrap(const Center(child: Text('Invalid YouTube link')), false);
    }

    final c = _controller;
    if (c == null) {
      return _wrap(const Center(child: CircularProgressIndicator()), false);
    }

    final ytPlayer = YoutubePlayer(
      controller: c,
      aspectRatio: 16 / 9,
      showVideoProgressIndicator: true,
    );

    return YoutubePlayerBuilder(
      player: ytPlayer,
      onEnterFullScreen: _enterFullscreen,
      onExitFullScreen: _exitFullscreen,
      builder: (context, player) {
        return ValueListenableBuilder<YoutubePlayerValue>(
          valueListenable: c,
          builder: (context, value, _) {
            final full = value.isFullScreen;

            // ✅ Fullscreen: ONLY the player (no card padding/clipping context).
            if (full) {
              return ColoredBox(
                color: Colors.black,
                child: Center(child: player),
              );
            }

            return _wrap(player, false);
          },
        );
      },
    );
  }

  Widget _wrap(Widget child, bool fullScreen) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(fullScreen ? 0 : widget.borderRadius),
      child: child,
    );
  }
}
