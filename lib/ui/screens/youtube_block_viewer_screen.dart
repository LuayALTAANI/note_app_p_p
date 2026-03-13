// lib/ui/screens/youtube_block_viewer_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../widgets/youtube_focused_player.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../common/confirm_dialog.dart';
import '../common/snackbar.dart';
import '../screens/item/item_block_meta.dart';
import '../screens/item/item_rename_dialog.dart';
import '../screens/item/item_share.dart';
import '../common/video_meta.dart';

class YoutubeBlockViewerScreen extends ConsumerStatefulWidget {
  const YoutubeBlockViewerScreen({super.key, required this.blockId});

  final String blockId;

  @override
  ConsumerState<YoutubeBlockViewerScreen> createState() =>
      _YoutubeBlockViewerScreenState();
}

class _YoutubeBlockViewerScreenState
    extends ConsumerState<YoutubeBlockViewerScreen> {
  bool _isFullScreen = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return StreamBuilder<DetailBlock?>(
      stream: (db.select(
        db.detailBlocks,
      )..where((t) => t.id.equals(widget.blockId))).watchSingleOrNull(),
      builder: (context, snap) {
        final block = snap.data;
        if (block == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final yt = metaYoutubeUrl(block.meta);
        final title = blockTitle(block);
        return Scaffold(
          backgroundColor: _isFullScreen ? Colors.black : null,
          appBar: _isFullScreen
              ? null
              : AppBar(
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      onPressed: () async {
                        final url = await showRenameDialog(context, yt ?? '');
                        final v = (url ?? '').trim();
                        if (v.isEmpty) {
                          await setBlockYoutubeUrl(db, block, null);
                          if (context.mounted) {
                            showSnack(context, 'YouTube link removed');
                          }
                          return;
                        }
                        if (tryExtractYoutubeId(v) == null) {
                          if (context.mounted) {
                            showSnack(context, 'Invalid YouTube link');
                          }
                          return;
                        }
                        await setBlockYoutubeUrl(db, block, v);
                        if (context.mounted) {
                          showSnack(context, 'YouTube link saved');
                        }
                      },
                      icon: const Icon(Icons.change_circle),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => shareBlock(context, db, block),
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
                          message: 'Remove this YouTube block?',
                        );
                        if (!ok) return;
                        await db.blocksDao.deleteBlock(block.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
          body: (yt == null || tryExtractYoutubeId(yt) == null)
              ? const Center(child: Text('Invalid / missing YouTube link'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: YoutubeFocusedPlayer(youtubeUrl: yt),
                ),
        );
      },
    );
  }
}

class _YoutubeFullscreenAwarePlayer extends StatefulWidget {
  const _YoutubeFullscreenAwarePlayer({
    required this.youtubeUrl,
    required this.onFullscreenChanged,
  });

  final String youtubeUrl;
  final ValueChanged<bool> onFullscreenChanged;

  @override
  State<_YoutubeFullscreenAwarePlayer> createState() =>
      _YoutubeFullscreenAwarePlayerState();
}

class _YoutubeFullscreenAwarePlayerState
    extends State<_YoutubeFullscreenAwarePlayer> {
  YoutubePlayerController? _controller;
  bool _lastFull = false;

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
  void didUpdateWidget(covariant _YoutubeFullscreenAwarePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeUrl.trim() != widget.youtubeUrl.trim()) {
      _controller?.dispose();
      _controller = null;
      _lastFull = false;
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
    if (id == null) return const Center(child: Text('Invalid YouTube link'));

    final c = _controller;
    if (c == null) return const Center(child: CircularProgressIndicator());

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

            if (full != _lastFull) {
              _lastFull = full;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onFullscreenChanged(full);
              });
            }

            // ✅ Fullscreen: ONLY show the player, no extra UI, no clipping.
            if (full) {
              return ColoredBox(
                color: Colors.black,
                child: Center(child: player),
              );
            }

            // Normal: clip + allow surrounding UI.
            return Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: player,
              ),
            );
          },
        );
      },
    );
  }
}
