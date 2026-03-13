import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({
    super.key,
    required this.file,
    this.compact = false,
    this.showTimes = true,
  });

  final File file;

  /// Compact UI: smaller paddings + smaller waveform/slider height.
  final bool compact;

  /// Show elapsed + total time (in the same row).
  final bool showTimes;

  static Future<bool> recordToFile(
    BuildContext context, {
    required String outputPath,
  }) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    final rec = AudioRecorder();
    try {
      final can = await rec.hasPermission();
      if (!can) return false;

      await rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: outputPath,
      );

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RecordingDialog(rec: rec),
      );
      return ok ?? false;
    } finally {
      await rec.dispose();
    }
  }

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _player = AudioPlayer();

  StreamSubscription<PlayerState>? _stateSub;
  Future<Waveform?>? _waveformFuture;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _waveformFuture = _loadOrCreateWaveform(widget.file);

    _stateSub = _player.playerStateStream.listen((s) async {
      if (s.processingState == ProcessingState.completed) {
        // Requirement: snap back to 0 and pause at end.
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    });
  }

  Future<void> _initPlayer() async {
    if (!await widget.file.exists()) return;
    await _player.setFilePath(widget.file.path);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.file.existsSync()) {
      return const Text('Audio file unavailable');
    }

    final iconSize = widget.compact ? 20.0 : 24.0;
    final buttonPad = widget.compact ? EdgeInsets.zero : const EdgeInsets.all(8);
    final constraints =
        widget.compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null;

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, stateSnap) {
        final state = stateSnap.data;
        final playing = state?.playing ?? false;
        final processing = state?.processingState ?? ProcessingState.idle;

        return StreamBuilder<Duration?>(
          stream: _player.durationStream,
          builder: (context, dSnap) {
            final total = dSnap.data ?? Duration.zero;

            return StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, pSnap) {
                final pos = pSnap.data ?? Duration.zero;

                final totalMs = max(1, total.inMilliseconds);
                final posMs = pos.inMilliseconds.clamp(0, totalMs);

                Future<void> togglePlayPause() async {
                  final atEnd = total > Duration.zero && posMs >= totalMs;
                  if (processing == ProcessingState.completed || atEnd) {
                    await _player.seek(Duration.zero);
                  }
                  if (_player.playing) {
                    await _player.pause();
                  } else {
                    await _player.play();
                  }
                }

                return Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    IconButton(
                      visualDensity:
                          widget.compact ? VisualDensity.compact : VisualDensity.standard,
                      padding: buttonPad,
                      constraints: constraints,
                      iconSize: iconSize,
                      onPressed: togglePlayPause,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    if (widget.showTimes) ...[
                      Text(_fmt(Duration(milliseconds: posMs))),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FutureBuilder<Waveform?>(
                        future: _waveformFuture,
                        builder: (context, wfSnap) {
                          final wf = wfSnap.data;

                          // Taller waveform (per your request)
                          final h = widget.compact ? 34.0 : 52.0;

                          if (wf == null) {
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: widget.compact ? 2.5 : null,
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: widget.compact ? 6 : 8,
                                ),
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: widget.compact ? 10 : 14,
                                ),
                              ),
                              child: Slider(
                                value: posMs.toDouble(),
                                max: totalMs.toDouble(),
                                onChanged: (v) => _player.seek(
                                  Duration(milliseconds: v.toInt()),
                                ),
                              ),
                            );
                          }

                          return _WaveformSeekBar(
                            height: h,
                            waveform: wf,
                            positionMs: posMs,
                            durationMs: totalMs,
                            compact: widget.compact,
                            onSeekMs: (ms) => _player.seek(Duration(milliseconds: ms)),
                          );
                        },
                      ),
                    ),
                    if (widget.showTimes) ...[
                      const SizedBox(width: 8),
                      Text(_fmt(total)),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _WaveformSeekBar extends StatelessWidget {
  const _WaveformSeekBar({
    required this.height,
    required this.waveform,
    required this.positionMs,
    required this.durationMs,
    required this.onSeekMs,
    required this.compact,
  });

  final double height;
  final Waveform waveform;
  final int positionMs;
  final int durationMs;
  final ValueChanged<int> onSeekMs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = max(1.0, c.maxWidth);
        int msFromDx(double dx) {
          final t = (dx / w).clamp(0.0, 1.0);
          return (t * durationMs).round();
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => onSeekMs(msFromDx(d.localPosition.dx)),
          onPanUpdate: (d) => onSeekMs(msFromDx(d.localPosition.dx)),
          onTapDown: (d) => onSeekMs(msFromDx(d.localPosition.dx)),
          child: SizedBox(
            height: height,
            child: CustomPaint(
              painter: _WaveformPainter(
                waveform: waveform,
                progress: durationMs <= 0 ? 0.0 : (positionMs / durationMs).clamp(0.0, 1.0),
                theme: Theme.of(context),
                compact: compact,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.theme,
    required this.compact,
  });

  final Waveform waveform;
  final double progress;
  final ThemeData theme;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final data = waveform.data;
    if (data.isEmpty) return;

    final pixels = data.length ~/ 2;
    if (pixels <= 0) return;

    final centerY = size.height / 2;

    // Bigger wave peaks (per your request), but keep a bit of padding to avoid clipping.
    final amp = size.height * (compact ? 0.60 : 0.62);

    final stepX = size.width / pixels;
    final playedCount = (pixels * progress).floor().clamp(0, pixels);

    final playedPaint = Paint()
      ..color = theme.colorScheme.primary
      // Slightly thicker strokes to look "bigger".
      ..strokeWidth = compact ? 2.0 : 2.6
      ..strokeCap = StrokeCap.round;

    final unplayedPaint = Paint()
      ..color = theme.colorScheme.onSurfaceVariant.withOpacity(0.55)
      ..strokeWidth = compact ? 2.0 : 2.6
      ..strokeCap = StrokeCap.round;

    void drawRange(int start, int end, Paint paint) {
      for (var i = start; i < end; i++) {
        final minS = data[i * 2].toDouble();
        final maxS = data[i * 2 + 1].toDouble();

        // 16-bit PCM min/max.
        final minN = (minS / 32768.0).clamp(-1.0, 1.0);
        final maxN = (maxS / 32768.0).clamp(-1.0, 1.0);

        final x = (i + 0.5) * stepX;
        final y1 = centerY - (maxN * amp);
        final y2 = centerY - (minN * amp);

        canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
      }
    }

    drawRange(0, playedCount, playedPaint);
    drawRange(playedCount, pixels, unplayedPaint);

    final mid = Paint()
      ..color = theme.dividerColor.withOpacity(0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), mid);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.progress != progress ||
        old.waveform.data != waveform.data ||
        old.compact != compact ||
        old.theme.brightness != theme.brightness ||
        old.theme.colorScheme.primary != theme.colorScheme.primary;
  }
}

Future<Waveform?> _loadOrCreateWaveform(File audioFile) async {
  try {
    if (!await audioFile.exists()) return null;

    final tmp = await getTemporaryDirectory();
    final stat = await audioFile.stat();
    final key = '${p.basename(audioFile.path)}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
    final out = File(p.join(tmp.path, 'wave_${key.hashCode}.dat'));

    if (!await out.exists()) {
      await for (final _ in JustWaveform.extract(
        audioInFile: audioFile,
        waveOutFile: out,
        zoom: const WaveformZoom.pixelsPerSecond(90),
      )) {
        // progress stream (ignored)
      }
    }

    return JustWaveform.parse(out);
  } catch (_) {
    return null;
  }
}

class _RecordingDialog extends StatefulWidget {
  const _RecordingDialog({required this.rec});
  final AudioRecorder rec;

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  bool _recording = true;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_recording) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _recording ? 'Recording' : 'Stopped',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _fmt(_elapsed),
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _LiveAudioWave(rec: widget.rec, active: _recording),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await widget.rec.stop();
                      if (!mounted) return;
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await widget.rec.stop();
                      if (!mounted) return;
                      setState(() => _recording = false);
                      Navigator.pop(context, true);
                    },
                    child: const Text('Stop & Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveAudioWave extends StatefulWidget {
  const _LiveAudioWave({required this.rec, required this.active});
  final AudioRecorder rec;
  final bool active;

  @override
  State<_LiveAudioWave> createState() => _LiveAudioWaveState();
}

class _LiveAudioWaveState extends State<_LiveAudioWave> {
  StreamSubscription<Amplitude>? _sub;
  final List<double> _levels = List<double>.filled(24, 0.0, growable: true);

  @override
  void initState() {
    super.initState();
    _sub = widget.rec
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      if (!widget.active) return;
      final db = amp.current.clamp(-60.0, 0.0);
      final normalized = (db + 60) / 60;
      setState(() {
        _levels.removeAt(0);
        _levels.add(normalized);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _levels.map((v) {
          final h = 8 + pow(v, 1.4) * 52;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 4,
              height: h.toDouble(),
              decoration: BoxDecoration(
                color: widget.active ? Colors.redAccent : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
