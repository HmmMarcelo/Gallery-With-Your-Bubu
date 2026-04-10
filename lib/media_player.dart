import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'media_types.dart';

class InAppMediaPlayer extends StatefulWidget {
  final MediaFile file;

  const InAppMediaPlayer({super.key, required this.file});

  @override
  State<InAppMediaPlayer> createState() => _InAppMediaPlayerState();
}

class _InAppMediaPlayerState extends State<InAppMediaPlayer> {
  late final Player _player;
  late final VideoController _videoController;
  bool _isVideo = true;

  // State
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _volume = 100.0;
  double _speed = 1.0;
  bool _showControls = true;

  // Cut/trim
  bool _cutMode = false;
  Duration _cutStart = Duration.zero;
  Duration _cutEnd = Duration.zero;
  bool _isCutting = false;

  static const List<double> speedOptions = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
    4.0,
    5.0,
  ];

  @override
  void initState() {
    super.initState();
    final ext = p.extension(widget.file.path).toLowerCase();
    _isVideo = videoExtensions.contains(ext);

    _player = Player();
    _videoController = VideoController(_player);

    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.stream.duration.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur;
          _cutEnd = dur;
        });
      }
    });
    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _playing = playing);
    });
    _player.stream.volume.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    });
    _player.stream.rate.listen((rate) {
      if (mounted) setState(() => _speed = rate);
    });

    _player.open(Media(widget.file.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _cutAndSave() async {
    if (_cutStart >= _cutEnd) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start time must be before end time')),
        );
      }
      return;
    }

    // Show quality/format picker
    final options = await showDialog<_TrimOptions>(
      context: context,
      builder: (context) => _TrimOptionsDialog(
        sourceSize: widget.file.size,
        cutDuration: _cutEnd - _cutStart,
        totalDuration: _duration,
        sourceExt: p.extension(widget.file.path).toLowerCase(),
      ),
    );
    if (options == null) return;

    // Pick save location
    final outputExt = options.format == 'gif'
        ? '.gif'
        : p.extension(widget.file.path);
    final baseName = p.basenameWithoutExtension(widget.file.path);
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save trimmed file',
      fileName: '${baseName}_trimmed$outputExt',
      type: FileType.any,
    );
    if (result == null) return;

    setState(() => _isCutting = true);

    try {
      final startSec = _cutStart.inMilliseconds / 1000.0;
      final durationSec = (_cutEnd - _cutStart).inMilliseconds / 1000.0;

      final args = <String>[
        '-y',
        '-i',
        widget.file.path,
        '-ss',
        startSec.toStringAsFixed(3),
        '-t',
        durationSec.toStringAsFixed(3),
      ];

      if (options.format == 'gif') {
        final h = options.resolution == 'same' ? '480' : options.resolution;
        args.addAll(['-vf', 'fps=15,scale=-1:$h:flags=lanczos', '-f', 'gif']);
      } else if (options.resolution == 'same') {
        args.addAll(['-c', 'copy']);
      } else {
        args.addAll([
          '-vf',
          'scale=-2:${options.resolution}',
          '-c:v',
          'libx264',
          '-crf',
          '23',
          '-c:a',
          'copy',
        ]);
      }

      args.add(result);

      final ffmpegResult = await Process.run('ffmpeg', args);

      if (mounted) {
        if (ffmpegResult.exitCode == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to: ${p.basename(result)}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'FFmpeg error: ${ffmpegResult.stderr.toString().split('\n').last}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'FFmpeg not found. Install FFmpeg to use cut feature.\n$e',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCutting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // Video/Audio content
            if (_isVideo)
              ExcludeSemantics(
                child: Center(
                  child: Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF7C4DFF),
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p.basename(widget.file.path),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Controls overlay
            if (_showControls) ...[
              // Top bar - back and title
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              p.basename(widget.file.path),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Cut range indicators
                          if (_cutMode) _buildCutBar(),

                          // Seek bar
                          _buildSeekBar(),

                          // Time labels
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Controls row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Speed selector
                              _SpeedButton(
                                speed: _speed,
                                onSpeedChanged: (speed) {
                                  _player.setRate(speed);
                                },
                              ),
                              const SizedBox(width: 12),

                              // Skip backward 10s
                              IconButton(
                                icon: const Icon(
                                  Icons.replay_10,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  final newPos =
                                      _position - const Duration(seconds: 10);
                                  _player.seek(
                                    newPos < Duration.zero
                                        ? Duration.zero
                                        : newPos,
                                  );
                                },
                              ),

                              // Play/Pause
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C4DFF),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  onPressed: () => _player.playOrPause(),
                                ),
                              ),

                              // Skip forward 10s
                              IconButton(
                                icon: const Icon(
                                  Icons.forward_10,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  final newPos =
                                      _position + const Duration(seconds: 10);
                                  _player.seek(
                                    newPos > _duration ? _duration : newPos,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),

                              // Volume
                              _VolumeButton(
                                volume: _volume,
                                onVolumeChanged: (vol) {
                                  _player.setVolume(vol);
                                },
                              ),

                              const Spacer(),

                              // Cut/trim toggle
                              IconButton(
                                icon: Icon(
                                  Icons.content_cut,
                                  color: _cutMode
                                      ? const Color(0xFF7C4DFF)
                                      : Colors.white70,
                                  size: 22,
                                ),
                                tooltip: 'Cut/Trim',
                                onPressed: () {
                                  setState(() {
                                    _cutMode = !_cutMode;
                                    if (_cutMode) {
                                      _cutStart = Duration.zero;
                                      _cutEnd = _duration;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Cutting progress overlay
            if (_isCutting)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                      SizedBox(height: 16),
                      Text(
                        'Trimming...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    final totalMs = _duration.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble().clamp(
      0.0,
      totalMs > 0 ? totalMs : 1.0,
    );

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: const Color(0xFF7C4DFF),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
        thumbColor: const Color(0xFF7C4DFF),
      ),
      child: Slider(
        min: 0,
        max: totalMs > 0 ? totalMs : 1.0,
        value: posMs,
        onChanged: (val) {
          _player.seek(Duration(milliseconds: val.round()));
        },
      ),
    );
  }

  Widget _buildCutBar() {
    final totalMs = _duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut, size: 14, color: Color(0xFF7C4DFF)),
              const SizedBox(width: 6),
              Text(
                'Start: ${_formatDuration(_cutStart)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                'End: ${_formatDuration(_cutEnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _cutStart = _position;
                    if (_cutStart > _cutEnd) _cutEnd = _cutStart;
                  });
                },
                icon: const Icon(Icons.start, size: 14),
                label: const Text('Set Start', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _cutEnd = _position;
                    if (_cutEnd < _cutStart) _cutStart = _cutEnd;
                  });
                },
                icon: const Icon(Icons.stop, size: 14),
                label: const Text('Set End', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          // Cut range slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: const Color(0xFF7C4DFF),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 6,
              ),
            ),
            child: RangeSlider(
              min: 0,
              max: totalMs,
              values: RangeValues(
                _cutStart.inMilliseconds.toDouble().clamp(0, totalMs),
                _cutEnd.inMilliseconds.toDouble().clamp(
                  _cutStart.inMilliseconds.toDouble().clamp(0, totalMs),
                  totalMs,
                ),
              ),
              onChanged: (values) {
                setState(() {
                  _cutStart = Duration(milliseconds: values.start.round());
                  _cutEnd = Duration(milliseconds: values.end.round());
                });
              },
            ),
          ),
          // Save button
          FilledButton.icon(
            onPressed: _isCutting ? null : _cutAndSave,
            icon: const Icon(Icons.save, size: 16),
            label: Text(
              'Save ${_formatDuration(_cutEnd - _cutStart)}',
              style: const TextStyle(fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// Speed selector popup button
class _SpeedButton extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  const _SpeedButton({required this.speed, required this.onSpeedChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      offset: const Offset(0, -300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => _InAppMediaPlayerState.speedOptions
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              child: Row(
                children: [
                  if ((s - speed).abs() < 0.01)
                    const Icon(Icons.check, size: 16, color: Color(0xFF7C4DFF))
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${s}x',
                    style: TextStyle(
                      fontWeight: (s - speed).abs() < 0.01
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onSelected: onSpeedChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: speed != 1.0
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: speed != 1.0 ? const Color(0xFF7C4DFF) : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Volume button with slider popup
class _VolumeButton extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const _VolumeButton({required this.volume, required this.onVolumeChanged});

  @override
  State<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<_VolumeButton> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 40,
                height: 140,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: StatefulBuilder(
                  builder: (context, setOverlayState) {
                    return RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          activeTrackColor: const Color(0xFF7C4DFF),
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.2,
                          ),
                          thumbColor: const Color(0xFF7C4DFF),
                        ),
                        child: Slider(
                          min: 0,
                          max: 100,
                          value: widget.volume,
                          onChanged: (val) {
                            widget.onVolumeChanged(val);
                            setOverlayState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: Icon(
          widget.volume > 50
              ? Icons.volume_up
              : widget.volume > 0
              ? Icons.volume_down
              : Icons.volume_off,
          color: Colors.white,
          size: 24,
        ),
        tooltip: 'Volume',
        onPressed: _toggleOverlay,
      ),
    );
  }
}

// Trim options data
class _TrimOptions {
  final String resolution; // 'same', '1440', '1080', '720', '480'
  final String format; // 'same', 'gif'
  const _TrimOptions({required this.resolution, required this.format});
}

// Trim options dialog with quality, resolution, format, and estimated size
class _TrimOptionsDialog extends StatefulWidget {
  final int sourceSize;
  final Duration cutDuration;
  final Duration totalDuration;
  final String sourceExt;

  const _TrimOptionsDialog({
    required this.sourceSize,
    required this.cutDuration,
    required this.totalDuration,
    required this.sourceExt,
  });

  @override
  State<_TrimOptionsDialog> createState() => _TrimOptionsDialogState();
}

class _TrimOptionsDialogState extends State<_TrimOptionsDialog> {
  String _resolution = 'same';
  String _format = 'same';

  String _estimateSize() {
    final totalMs = widget.totalDuration.inMilliseconds;
    if (totalMs <= 0) return 'Unknown';
    final ratio = widget.cutDuration.inMilliseconds / totalMs;
    var estimate = (widget.sourceSize * ratio).round();

    if (_resolution != 'same') {
      const scales = {'1440': 0.56, '1080': 0.30, '720': 0.14, '480': 0.07};
      estimate = (estimate * (scales[_resolution] ?? 1.0)).round();
    }

    if (_format == 'gif') {
      estimate = (estimate * 2.5).round();
    }

    return '~${formatFileSize(estimate)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.tune, color: Color(0xFF7C4DFF)),
          SizedBox(width: 10),
          Text('Trim Options', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resolution:',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          DropdownButton<String>(
            value: _resolution,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'same', child: Text('Same as source')),
              DropdownMenuItem(
                value: '1440',
                child: Text('2K (2560\u00d71440)'),
              ),
              DropdownMenuItem(
                value: '1080',
                child: Text('1080p (1920\u00d71080)'),
              ),
              DropdownMenuItem(
                value: '720',
                child: Text('720p (1280\u00d7720)'),
              ),
              DropdownMenuItem(
                value: '480',
                child: Text('480p (854\u00d7480)'),
              ),
            ],
            onChanged: (val) => setState(() => _resolution = val!),
          ),
          const SizedBox(height: 16),
          const Text(
            'Format:',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          DropdownButton<String>(
            value: _format,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: 'same',
                child: Text('Same as source (${widget.sourceExt})'),
              ),
              const DropdownMenuItem(
                value: 'gif',
                child: Text('GIF (animated)'),
              ),
            ],
            onChanged: (val) => setState(() => _format = val!),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Text(
                  'Estimated size: ${_estimateSize()}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (_resolution != 'same')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Note: Re-encoding may take longer than copy mode.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          if (_format == 'gif')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'GIFs are typically much larger than video files.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _TrimOptions(resolution: _resolution, format: _format),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
