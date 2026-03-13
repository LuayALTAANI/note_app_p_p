// lib/ui/widgets/youtube_focused_player.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../common/video_meta.dart';

class YoutubeFocusedPlayer extends StatefulWidget {
  const YoutubeFocusedPlayer({
    super.key,
    required this.youtubeUrl,
    this.borderRadius = 12,
  });

  final String youtubeUrl;
  final double borderRadius;

  @override
  State<YoutubeFocusedPlayer> createState() => _YoutubeFocusedPlayerState();
}

class _YoutubeFocusedPlayerState extends State<YoutubeFocusedPlayer> {
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
  void didUpdateWidget(covariant YoutubeFocusedPlayer oldWidget) {
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

  double _safePlaybackRate(YoutubePlayerController c) {
    try {
      final r = c.value.playbackRate;
      if (r.isFinite && r > 0) return r;
    } catch (_) {}
    return 1.0;
  }

  Future<void> _setPlaybackRateSafe(
    YoutubePlayerController c,
    double rate,
  ) async {
    try {
      c.setPlaybackRate(rate);
    } catch (_) {}
  }

  Future<void> _openFullscreen() async {
    final c = _controller;
    if (c == null) return;

    final startAt = c.value.position;
    final wasPlaying = c.value.isPlaying;
    final rate = _safePlaybackRate(c);

    // ✅ prevent overlap echo during handoff
    try {
      c.pause();
    } catch (_) {}

    final res = await Navigator.of(context).push<_FullscreenResult>(
      PageRouteBuilder<_FullscreenResult>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, __, ___) => _YoutubeFullscreenPage(
          youtubeUrl: widget.youtubeUrl,
          startAt: startAt,
          resumePlaying: wasPlaying,
          playbackRate: rate,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );

    if (res == null) {
      try {
        c.seekTo(startAt);
        _setPlaybackRateSafe(c, rate);
        if (wasPlaying) c.play();
      } catch (_) {}
      return;
    }

    try {
      c.seekTo(res.position);
      _setPlaybackRateSafe(c, res.playbackRate);
      if (res.shouldPlay) {
        c.play();
      } else {
        c.pause();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final id = tryExtractYoutubeId(widget.youtubeUrl);
    if (id == null) return const Center(child: Text('Invalid YouTube link'));

    final c = _controller;
    if (c == null) return const Center(child: CircularProgressIndicator());

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: YoutubePlayer(
        controller: c,
        aspectRatio: 16 / 9,
        showVideoProgressIndicator: true,
        bottomActions: [
          const CurrentPosition(),
          const SizedBox(width: 8),
          Expanded(
            child: ProgressBar(
              isExpanded: true,
              colors: ProgressBarColors(
                playedColor: Theme.of(context).colorScheme.primary,
                handleColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const RemainingDuration(),
          const PlaybackSpeedButton(),
          IconButton(
            tooltip: 'Fullscreen',
            icon: const Icon(Icons.fullscreen),
            onPressed: _openFullscreen,
          ),
        ],
      ),
    );
  }
}

class _YoutubeFullscreenPage extends StatefulWidget {
  const _YoutubeFullscreenPage({
    required this.youtubeUrl,
    required this.startAt,
    required this.resumePlaying,
    required this.playbackRate,
  });

  final String youtubeUrl;
  final Duration startAt;
  final bool resumePlaying;
  final double playbackRate;

  @override
  State<_YoutubeFullscreenPage> createState() => _YoutubeFullscreenPageState();
}

enum _GestureZone { left, middle, right, none }

enum _HudKind { none, volume, brightness }

class _YoutubeFullscreenPageState extends State<_YoutubeFullscreenPage> {
  YoutubePlayerController? _c;

  bool _didApplyStart = false;
  bool _ready = false;

  // Gesture state
  _GestureZone _zone = _GestureZone.none;
  double _startDy = 0;
  double _startValue = 0;
  bool _didExitBySwipe = false;

  // Device state
  final _brightness = ScreenBrightness();
  final _volume = VolumeController.instance;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;

  // HUD
  _HudKind _hud = _HudKind.none;
  double _hudValue = 0;
  String _hudText = '';
  IconData _hudIcon = Icons.tune;

  @override
  void initState() {
    super.initState();
    _enterImmersive();
    _initController();
    _initDeviceState();
  }

  void _initController() {
    final id = tryExtractYoutubeId(widget.youtubeUrl);
    if (id == null) return;

    _c = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        controlsVisibleAtStart: true,
        enableCaption: true,
      ),
    );
  }

  Future<void> _initDeviceState() async {
    if (kIsWeb) return;
    try {
      _currentBrightness = (await _brightness.current).clamp(0.0, 1.0);
    } catch (_) {}
    try {
      _currentVolume = (await _volume.getVolume()).clamp(0.0, 1.0);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _enterImmersive() async {
    if (kIsWeb) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitImmersive() async {
    if (kIsWeb) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _close() async {
    final c = _c;
    final pos = c?.value.position ?? Duration.zero;
    final playing = c?.value.isPlaying ?? false;
    final rate = c?.value.playbackRate ?? 1.0;

    await _exitImmersive();
    if (!mounted) return;

    Navigator.of(context).pop(
      _FullscreenResult(position: pos, shouldPlay: playing, playbackRate: rate),
    );
  }

  @override
  void dispose() {
    _c?.dispose();
    _exitImmersive();
    super.dispose();
  }

  _GestureZone _zoneForDx(BuildContext context, double dx) {
    final w = MediaQuery.of(context).size.width;
    if (w <= 0) return _GestureZone.none;

    final leftEnd = w * 0.33;
    final rightStart = w * 0.67;

    if (dx < leftEnd) return _GestureZone.left;
    if (dx > rightStart) return _GestureZone.right;
    return _GestureZone.middle;
  }

  Future<void> _applyBrightness(double v) async {
    final nv = v.clamp(0.0, 1.0);
    _currentBrightness = nv;
    try {
      await _brightness.setScreenBrightness(nv);
    } catch (_) {}
  }

  Future<void> _applyVolume(double v) async {
    final nv = v.clamp(0.0, 1.0);
    _currentVolume = nv;
    try {
      await _volume.setVolume(nv);
    } catch (_) {}
  }

  void _showHud(_HudKind kind, double v) {
    _hud = kind;
    _hudValue = v.clamp(0.0, 1.0);
    final pct = (_hudValue * 100).round();
    if (kind == _HudKind.volume) {
      _hudIcon = Icons.volume_up;
      _hudText = 'Volume $pct%';
    } else {
      _hudIcon = Icons.brightness_6;
      _hudText = 'Brightness $pct%';
    }
    if (mounted) setState(() {});
  }

  void _hideHud() {
    _hud = _HudKind.none;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final id = tryExtractYoutubeId(widget.youtubeUrl);
    if (id == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Invalid YouTube link',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final c = _c;
    if (c == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _close();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Player
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(
                    controller: c,
                    showVideoProgressIndicator: true,
                    onReady: () async {
                      if (_didApplyStart) return;
                      _didApplyStart = true;

                      try {
                        if (widget.startAt > Duration.zero) {
                          c.seekTo(widget.startAt);
                        }
                        c.setPlaybackRate(widget.playbackRate);
                        if (widget.resumePlaying) {
                          c.play();
                        }
                      } catch (_) {}

                      if (mounted) setState(() => _ready = true);
                    },
                    bottomActions: [
                      const CurrentPosition(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ProgressBar(
                          isExpanded: true,
                          colors: ProgressBarColors(
                            playedColor: Theme.of(context).colorScheme.primary,
                            handleColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const RemainingDuration(),
                      const PlaybackSpeedButton(),
                      IconButton(
                        tooltip: 'Exit fullscreen',
                        icon: const Icon(Icons.fullscreen_exit),
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ Gesture layer (only handles vertical drags; taps still go to player controls)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (d) async {
                    _didExitBySwipe = false;
                    _startDy = d.globalPosition.dy;
                    _zone = _zoneForDx(context, d.localPosition.dx);

                    if (_zone == _GestureZone.right) {
                      _startValue = _currentVolume;
                      _showHud(_HudKind.volume, _currentVolume);
                    } else if (_zone == _GestureZone.left) {
                      _startValue = _currentBrightness;
                      _showHud(_HudKind.brightness, _currentBrightness);
                    } else {
                      _startValue = 0;
                      _hideHud();
                    }
                  },
                  onVerticalDragUpdate: (d) async {
                    final size = MediaQuery.of(context).size;
                    final h = size.height <= 0 ? 1.0 : size.height;

                    final dy = d.globalPosition.dy - _startDy;

                    // ✅ Middle swipe down to exit
                    if (_zone == _GestureZone.middle && !_didExitBySwipe) {
                      if (dy > 120) {
                        _didExitBySwipe = true;
                        await _close();
                      }
                      return;
                    }

                    // Up = increase, Down = decrease
                    final delta = (-dy / h) * 1.6; // sensitivity
                    final next = (_startValue + delta).clamp(0.0, 1.0);

                    if (_zone == _GestureZone.right) {
                      await _applyVolume(next);
                      _showHud(_HudKind.volume, _currentVolume);
                    } else if (_zone == _GestureZone.left) {
                      await _applyBrightness(next);
                      _showHud(_HudKind.brightness, _currentBrightness);
                    }
                  },
                  onVerticalDragEnd: (_) => _hideHud(),
                  onVerticalDragCancel: () => _hideHud(),
                ),
              ),

              // Close button
              Positioned(
                top: 6,
                left: 6,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: _close,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),

              // HUD
              if (_hud != _HudKind.none)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_hudIcon, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          _hudText,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              // Handoff veil while seek+rate applied
              if (!_ready)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenResult {
  const _FullscreenResult({
    required this.position,
    required this.shouldPlay,
    required this.playbackRate,
  });

  final Duration position;
  final bool shouldPlay;
  final double playbackRate;
}
