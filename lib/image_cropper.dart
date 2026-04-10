import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

class ImageCropper extends StatefulWidget {
  final String filePath;
  const ImageCropper({super.key, required this.filePath});

  @override
  State<ImageCropper> createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  late Uint8List _imageBytes;
  Size _imageSize = Size.zero;
  bool _loading = true;
  bool _saving = false;

  Rect _cropRect = Rect.zero;
  Rect _imageRect = Rect.zero;
  Size _containerSize = Size.zero;

  int? _activeHandle;
  Offset _dragStart = Offset.zero;
  Rect _dragStartRect = Rect.zero;

  static const double _handleSize = 24;
  static const double _minCropSize = 40;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.filePath).readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    setState(() {
      _imageBytes = bytes;
      _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      _loading = false;
    });
  }

  void _updateLayout(Size containerSize) {
    if (_imageSize == Size.zero || containerSize == Size.zero) return;

    final oldImageRect = _imageRect;
    _containerSize = containerSize;

    final containerAspect = containerSize.width / containerSize.height;
    final imageAspect = _imageSize.width / _imageSize.height;

    double displayW, displayH, offsetX, offsetY;
    if (imageAspect > containerAspect) {
      displayW = containerSize.width;
      displayH = containerSize.width / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - displayH) / 2;
    } else {
      displayH = containerSize.height;
      displayW = containerSize.height * imageAspect;
      offsetX = (containerSize.width - displayW) / 2;
      offsetY = 0;
    }

    _imageRect = Rect.fromLTWH(offsetX, offsetY, displayW, displayH);

    if (_cropRect == Rect.zero || oldImageRect == Rect.zero) {
      _cropRect = _imageRect;
    } else if (oldImageRect != _imageRect) {
      final scaleX = _imageRect.width / oldImageRect.width;
      final scaleY = _imageRect.height / oldImageRect.height;
      _cropRect = Rect.fromLTRB(
        _imageRect.left + (_cropRect.left - oldImageRect.left) * scaleX,
        _imageRect.top + (_cropRect.top - oldImageRect.top) * scaleY,
        _imageRect.left + (_cropRect.right - oldImageRect.left) * scaleX,
        _imageRect.top + (_cropRect.bottom - oldImageRect.top) * scaleY,
      );
    }
  }

  int? _hitTestHandle(Offset point) {
    final handles = [
      _cropRect.topLeft,
      _cropRect.topRight,
      _cropRect.bottomRight,
      _cropRect.bottomLeft,
      Offset(_cropRect.center.dx, _cropRect.top),
      Offset(_cropRect.right, _cropRect.center.dy),
      Offset(_cropRect.center.dx, _cropRect.bottom),
      Offset(_cropRect.left, _cropRect.center.dy),
    ];
    for (int i = 0; i < handles.length; i++) {
      if ((handles[i] - point).distance < _handleSize) return i;
    }
    if (_cropRect.contains(point)) return 8;
    return null;
  }

  void _onPanStart(DragStartDetails details) {
    _activeHandle = _hitTestHandle(details.localPosition);
    _dragStart = details.localPosition;
    _dragStartRect = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeHandle == null) return;
    final delta = details.localPosition - _dragStart;
    Rect newRect;

    if (_activeHandle == 8) {
      newRect = _dragStartRect.shift(delta);
      double dx = 0, dy = 0;
      if (newRect.left < _imageRect.left) dx = _imageRect.left - newRect.left;
      if (newRect.top < _imageRect.top) dy = _imageRect.top - newRect.top;
      if (newRect.right > _imageRect.right) {
        dx = _imageRect.right - newRect.right;
      }
      if (newRect.bottom > _imageRect.bottom) {
        dy = _imageRect.bottom - newRect.bottom;
      }
      newRect = newRect.shift(Offset(dx, dy));
    } else {
      double left = _dragStartRect.left;
      double top = _dragStartRect.top;
      double right = _dragStartRect.right;
      double bottom = _dragStartRect.bottom;

      switch (_activeHandle!) {
        case 0:
          left += delta.dx;
          top += delta.dy;
        case 1:
          right += delta.dx;
          top += delta.dy;
        case 2:
          right += delta.dx;
          bottom += delta.dy;
        case 3:
          left += delta.dx;
          bottom += delta.dy;
        case 4:
          top += delta.dy;
        case 5:
          right += delta.dx;
        case 6:
          bottom += delta.dy;
        case 7:
          left += delta.dx;
      }

      left = left.clamp(_imageRect.left, _imageRect.right - _minCropSize);
      top = top.clamp(_imageRect.top, _imageRect.bottom - _minCropSize);
      right = right.clamp(_imageRect.left + _minCropSize, _imageRect.right);
      bottom = bottom.clamp(_imageRect.top + _minCropSize, _imageRect.bottom);

      if (right - left < _minCropSize) {
        if (_activeHandle == 0 || _activeHandle == 3 || _activeHandle == 7) {
          left = right - _minCropSize;
        } else {
          right = left + _minCropSize;
        }
      }
      if (bottom - top < _minCropSize) {
        if (_activeHandle == 0 || _activeHandle == 1 || _activeHandle == 4) {
          top = bottom - _minCropSize;
        } else {
          bottom = top + _minCropSize;
        }
      }

      newRect = Rect.fromLTRB(left, top, right, bottom);
    }

    setState(() => _cropRect = newRect);
  }

  void _onPanEnd(DragEndDetails details) {
    _activeHandle = null;
  }

  Rect _getImageCropRect() {
    if (_imageRect.width <= 0 || _imageRect.height <= 0) {
      return Rect.fromLTWH(0, 0, _imageSize.width, _imageSize.height);
    }
    final scale = _imageSize.width / _imageRect.width;
    return Rect.fromLTRB(
      ((_cropRect.left - _imageRect.left) * scale).roundToDouble(),
      ((_cropRect.top - _imageRect.top) * scale).roundToDouble(),
      ((_cropRect.right - _imageRect.left) * scale).roundToDouble(),
      ((_cropRect.bottom - _imageRect.top) * scale).roundToDouble(),
    );
  }

  Future<void> _saveAsCopy() async {
    final ext = p.extension(widget.filePath);
    final baseName = p.basenameWithoutExtension(widget.filePath);
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save cropped copy',
      fileName: '${baseName}_cropped$ext',
      type: FileType.any,
    );
    if (result == null) return;
    await _performCrop(result);
  }

  Future<void> _saveOriginal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Overwrite original?'),
        content: const Text(
          'This will replace the original file with the cropped version. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _performCrop(widget.filePath);
  }

  Future<void> _performCrop(String outputPath) async {
    setState(() => _saving = true);
    try {
      final cropRect = _getImageCropRect();
      final bytes = await File(widget.filePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');

      final x = cropRect.left.round().clamp(0, image.width - 1);
      final y = cropRect.top.round().clamp(0, image.height - 1);
      final w = cropRect.width.round().clamp(1, image.width - x);
      final h = cropRect.height.round().clamp(1, image.height - y);

      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

      final ext = p.extension(outputPath).toLowerCase();
      List<int> outputBytes;
      if (ext == '.jpg' || ext == '.jpeg' || ext == '.jfif') {
        outputBytes = img.encodeJpg(cropped, quality: 95);
      } else if (ext == '.bmp') {
        outputBytes = img.encodeBmp(cropped);
      } else if (ext == '.gif') {
        outputBytes = img.encodeGif(cropped);
      } else {
        outputBytes = img.encodePng(cropped);
      }

      await File(outputPath).writeAsBytes(outputBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: ${p.basename(outputPath)}')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cropping: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Crop Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _cropRect = _imageRect),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _updateLayout(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  return GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      children: [
                        Positioned(
                          left: _imageRect.left,
                          top: _imageRect.top,
                          width: _imageRect.width,
                          height: _imageRect.height,
                          child: Image.memory(_imageBytes, fit: BoxFit.fill),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CropOverlayPainter(cropRect: _cropRect),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final cr = _getImageCropRect();
                        return Text(
                          '${cr.width.round()} \u00d7 ${cr.height.round()} px',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _saveAsCopy,
                    icon: const Icon(Icons.save_as, size: 16),
                    label: const Text('Save Copy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveOriginal,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save Original'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_saving) const LinearProgressIndicator(color: Color(0xFF7C4DFF)),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, cropRect.top),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom),
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }

    final handlePaint = Paint()..color = Colors.white;
    final handles = [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomRight,
      cropRect.bottomLeft,
      Offset(cropRect.center.dx, cropRect.top),
      Offset(cropRect.right, cropRect.center.dy),
      Offset(cropRect.center.dx, cropRect.bottom),
      Offset(cropRect.left, cropRect.center.dy),
    ];

    for (final h in handles) {
      canvas.drawCircle(h, 5, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) {
    return old.cropRect != cropRect;
  }
}
