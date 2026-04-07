import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoThumbnailPreview extends StatefulWidget {
  final String filePath;
  final double previewSize;
  final Future<Uint8List?> Function(String, {int quality, int width})
  getThumbnail;

  const VideoThumbnailPreview({
    required this.filePath,
    required this.previewSize,
    required this.getThumbnail,
    super.key,
  });

  @override
  State<VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<VideoThumbnailPreview> {
  Uint8List? _thumb;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    setState(() => _loading = true);
    final thumb = await widget.getThumbnail(
      widget.filePath,
      quality: 70,
      width: (widget.previewSize * 2).toInt(),
    );
    if (mounted) {
      setState(() {
        _thumb = thumb;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_thumb != null) {
      return Image.memory(_thumb!, fit: BoxFit.cover);
    }
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white24, size: 36),
      ),
    );
  }
}
