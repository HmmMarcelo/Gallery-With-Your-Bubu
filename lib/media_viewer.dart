import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'media_types.dart';
import 'media_player.dart';
import 'image_cropper.dart';

class MediaViewer extends StatefulWidget {
  final List<MediaFile> files;
  final int initialIndex;
  final Future<Uint8List?> Function(String, {int quality, int width})
  getVideoThumbnail;

  const MediaViewer({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.getVideoThumbnail,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_currentIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_currentIndex < widget.files.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  MediaFile get _currentFile => widget.files[_currentIndex];

  void _showFileInfo() {
    final file = _currentFile;
    final name = p.basename(file.path);
    final ext = p.extension(file.path).toUpperCase().replaceFirst('.', '');
    final type = getMediaType(p.extension(file.path).toLowerCase());
    final typeLabel = switch (type) {
      MediaType.image => 'Image',
      MediaType.video => 'Video',
      MediaType.audio => 'Audio',
      _ => 'File',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoTile(Icons.insert_drive_file, 'Name', name),
              _infoTile(Icons.folder, 'Location', p.dirname(file.path)),
              _infoTile(Icons.category, 'Type', '$typeLabel ($ext)'),
              _infoTile(Icons.data_usage, 'Size', formatFileSize(file.size)),
              _infoTile(
                Icons.calendar_today,
                'Modified',
                formatDate(file.modified),
              ),
            ],
          ),
        ),
        actions: [
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                openFileLocation(file.path);
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Open Location'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentExt = p.extension(_currentFile.path).toLowerCase();
    final isImage = imageExtensions.contains(currentExt);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() => _showOverlay = !_showOverlay),
          child: Stack(
            children: [
              // Page view for swiping between media
              ExcludeSemantics(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.files.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    final file = widget.files[index];
                    final ext = p.extension(file.path).toLowerCase();
                    if (imageExtensions.contains(ext)) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        child: Center(
                          child: Image.file(
                            File(file.path),
                            errorBuilder: (c, e, s) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                  size: 64,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cannot display this format',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else if (videoExtensions.contains(ext)) {
                      return _VideoViewerPage(
                        file: file,
                        getVideoThumbnail: widget.getVideoThumbnail,
                      );
                    }
                    return const Center(
                      child: Icon(
                        Icons.insert_drive_file,
                        color: Colors.white24,
                        size: 64,
                      ),
                    );
                  },
                ),
              ),
              // Left navigation arrow
              if (_showOverlay && _currentIndex > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                ),
              // Right navigation arrow
              if (_showOverlay && _currentIndex < widget.files.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                ),
              // Top overlay bar
              if (_showOverlay)
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p.basename(_currentFile.path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${_currentIndex + 1} / ${widget.files.length}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isImage)
                              IconButton(
                                icon: const Icon(
                                  Icons.crop,
                                  color: Colors.white,
                                ),
                                tooltip: 'Crop',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ImageCropper(
                                        filePath: _currentFile.path,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                              ),
                              tooltip: 'Properties',
                              onPressed: _showFileInfo,
                            ),
                            if (Platform.isWindows ||
                                Platform.isMacOS ||
                                Platform.isLinux) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.folder_open,
                                  color: Colors.white,
                                ),
                                tooltip: 'Open file location',
                                onPressed: () =>
                                    openFileLocation(_currentFile.path),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.open_in_new,
                                  color: Colors.white,
                                ),
                                tooltip: 'Open with default app',
                                onPressed: () =>
                                    openFileExternal(_currentFile.path),
                              ),
                            ],
                          ],
                        ),
                      ),
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

// Video viewer page - opens in-app media player
class _VideoViewerPage extends StatelessWidget {
  final MediaFile file;
  final Future<Uint8List?> Function(String, {int quality, int width})
  getVideoThumbnail;

  const _VideoViewerPage({required this.file, required this.getVideoThumbnail});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => InAppMediaPlayer(file: file)),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: getVideoThumbnail(file.path, quality: 90, width: 800),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return SizedBox.expand(
                  child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                );
              }
              return const Center(
                child: Icon(Icons.videocam, color: Colors.white24, size: 64),
              );
            },
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
