import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:cross_platform_video_thumbnails/cross_platform_video_thumbnails.dart';
import 'media_types.dart';
import 'video_thumbnail_preview.dart';
import 'media_viewer.dart';
import 'media_player.dart';

class MediaGallery extends StatefulWidget {
  final List<String> initialDirectories;
  const MediaGallery({super.key, required this.initialDirectories});

  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  // --- Video thumbnail cache with concurrency limiter ---
  static final Map<String, Uint8List?> _videoThumbnails = {};
  static int _activeThumbLoads = 0;
  static const int _maxConcurrentThumbs = 3;
  static final List<Completer<Uint8List?>> _thumbQueue = [];
  static final List<Future<Uint8List?> Function()> _thumbTasks = [];

  static Future<Uint8List?> getVideoThumbnail(
    String path, {
    int quality = 50,
    int width = 256,
  }) async {
    if (_videoThumbnails.containsKey(path)) return _videoThumbnails[path];

    final completer = Completer<Uint8List?>();
    _thumbQueue.add(completer);
    _thumbTasks.add(() => _doLoadThumbnail(path, quality, width));
    _processThumbQueue();
    return completer.future;
  }

  static void _processThumbQueue() {
    while (_activeThumbLoads < _maxConcurrentThumbs && _thumbQueue.isNotEmpty) {
      _activeThumbLoads++;
      final completer = _thumbQueue.removeAt(0);
      final task = _thumbTasks.removeAt(0);
      task().then((result) {
        completer.complete(result);
        _activeThumbLoads--;
        _processThumbQueue();
      });
    }
  }

  static Future<Uint8List?> _doLoadThumbnail(
    String path,
    int quality,
    int width,
  ) async {
    if (_videoThumbnails.containsKey(path)) return _videoThumbnails[path];
    try {
      final thumbResult = await CrossPlatformVideoThumbnails.generateThumbnail(
        path,
        ThumbnailOptions(
          timePosition: 1.0,
          width: width,
          height: width,
          quality: quality / 100.0,
          format: ThumbnailFormat.png,
          maintainAspectRatio: true,
        ),
      );
      final thumb = Uint8List.fromList(thumbResult.data);
      if (thumb.isEmpty) {
        _videoThumbnails[path] = null;
        return null;
      }
      _videoThumbnails[path] = thumb;
      return thumb;
    } catch (e) {
      _videoThumbnails[path] = null;
      return null;
    }
  }

  // --- State ---
  late List<String> directories;
  double previewSize = 140;
  List<MediaFile> mediaFiles = [];
  List<MediaFile> filteredFiles = [];
  bool loading = true;
  String sortBy = 'date';
  bool sortAscending = false;
  bool showSectionHeaders = true;
  String searchText = '';
  DateTimeRange? dateRange;
  int _scanCount = 0;
  Set<String> _enabledExtensions = {};
  final TextEditingController _searchController = TextEditingController();

  static const sortOptions = [
    {'label': 'Date', 'value': 'date'},
    {'label': 'Size', 'value': 'size'},
    {'label': 'Name', 'value': 'name'},
  ];

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    directories = List.from(widget.initialDirectories);
    _enabledExtensions = Set.from(allSupportedExtensions);
    _scanMediaFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanMediaFiles() async {
    setState(() {
      loading = true;
      _scanCount = 0;
    });
    final files = <MediaFile>[];
    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (allSupportedExtensions.contains(ext)) {
              try {
                final stat = await entity.stat();
                files.add(
                  MediaFile(
                    path: entity.path,
                    type: stat.type,
                    size: stat.size,
                    modified: stat.modified,
                  ),
                );
                if (files.length % 100 == 0 && mounted) {
                  setState(() => _scanCount = files.length);
                }
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scanning $dirPath: $e')),
          );
        }
      }
    }
    _sortFiles(files);
    if (mounted) {
      setState(() {
        mediaFiles = files;
        _applyFilters();
        loading = false;
      });
    }
  }

  void _applyFilters() {
    filteredFiles = mediaFiles.where((file) {
      final ext = p.extension(file.path).toLowerCase();
      final matchesType = _enabledExtensions.contains(ext);
      final matchesText =
          searchText.isEmpty ||
          p.basename(file.path).toLowerCase().contains(searchText.toLowerCase());
      final matchesDate =
          dateRange == null ||
          (file.modified.isAfter(
                dateRange!.start.subtract(const Duration(days: 1)),
              ) &&
              file.modified.isBefore(
                dateRange!.end.add(const Duration(days: 1)),
              ));
      return matchesType && matchesText && matchesDate;
    }).toList();
    _sortFiles(filteredFiles);
  }

  void _sortFiles(List<MediaFile> files) {
    final dir = sortAscending ? 1 : -1;
    switch (sortBy) {
      case 'size':
        files.sort((a, b) => dir * a.size.compareTo(b.size));
      case 'name':
        files.sort(
          (a, b) =>
              dir *
              p.basename(a.path).toLowerCase().compareTo(
                    p.basename(b.path).toLowerCase(),
                  ),
        );
      default:
        files.sort((a, b) => dir * a.modified.compareTo(b.modified));
    }
  }

  // --- Folder Manager ---

  void _showFolderManager() {
    showDialog(
      context: context,
      builder: (context) => _FolderManagerDialog(
        directories: List.from(directories),
        onSave: (newDirs) {
          setState(() => directories = newDirs);
          _scanMediaFiles();
        },
      ),
    );
  }

  // --- Type Filter ---

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => _TypeFilterDialog(
        enabledExtensions: Set.from(_enabledExtensions),
        onSave: (newSet) {
          setState(() {
            _enabledExtensions = newSet;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: dateRange,
    );
    if (picked != null) {
      setState(() {
        dateRange = picked;
        _applyFilters();
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      dateRange = null;
      _applyFilters();
    });
  }

  void _openViewer(MediaFile file) {
    final viewableFiles = <MediaFile>[];
    int viewerIndex = 0;
    for (int i = 0; i < filteredFiles.length; i++) {
      final ext = p.extension(filteredFiles[i].path).toLowerCase();
      if (imageExtensions.contains(ext) || videoExtensions.contains(ext)) {
        if (identical(filteredFiles[i], file)) viewerIndex = viewableFiles.length;
        viewableFiles.add(filteredFiles[i]);
      }
    }
    if (viewableFiles.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaViewer(
          files: viewableFiles,
          initialIndex: viewerIndex,
          getVideoThumbnail: getVideoThumbnail,
        ),
      ),
    );
  }

  void _showContextMenu(MediaFile file, Offset position) {
    final ext = p.extension(file.path).toLowerCase();
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (imageExtensions.contains(ext) || videoExtensions.contains(ext))
          const PopupMenuItem(
            value: 'view',
            child: ListTile(
              leading: Icon(Icons.visibility, size: 20),
              title: Text('View'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isDesktop)
          const PopupMenuItem(
            value: 'open',
            child: ListTile(
              leading: Icon(Icons.open_in_new, size: 20),
              title: Text('Open with default app'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isDesktop)
          const PopupMenuItem(
            value: 'location',
            child: ListTile(
              leading: Icon(Icons.folder_open, size: 20),
              title: Text('Open file location'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: Icon(Icons.info_outline, size: 20),
            title: Text('Properties'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'view':
          _openViewer(file);
        case 'open':
          openFileExternal(file.path);
        case 'location':
          openFileLocation(file.path);
        case 'info':
          _showFileInfo(file);
      }
    });
  }

  void _showFileInfo(MediaFile file) {
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

  // --- Section grouping ---

  String _getSectionKey(MediaFile file) {
    switch (sortBy) {
      case 'date':
        return '${_monthNames[file.modified.month - 1]} ${file.modified.year}';
      case 'size':
        if (file.size < 100 * 1024) return 'Tiny (< 100 KB)';
        if (file.size < 1024 * 1024) return 'Small (100 KB \u2013 1 MB)';
        if (file.size < 10 * 1024 * 1024) return 'Medium (1 \u2013 10 MB)';
        if (file.size < 100 * 1024 * 1024) return 'Large (10 \u2013 100 MB)';
        return 'Huge (> 100 MB)';
      case 'name':
        final firstChar = p.basename(file.path).substring(0, 1).toUpperCase();
        return RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
      default:
        return 'All';
    }
  }

  List<_Section> _buildSections() {
    if (filteredFiles.isEmpty) return [];
    final groups = <String, List<MediaFile>>{};
    for (final f in filteredFiles) {
      final key = _getSectionKey(f);
      groups.putIfAbsent(key, () => []).add(f);
    }
    return groups.entries.map((e) => _Section(e.key, e.value)).toList();
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final typeFilterActive = _enabledExtensions.length < allSupportedExtensions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 52,
        title: Row(
          children: [
            // Folder manager button
            IconButton(
              icon: const Icon(Icons.folder_open, size: 20),
              tooltip: 'Manage folders',
              onPressed: _showFolderManager,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            // Search bar
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by filename...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchText = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) {
                    setState(() {
                      searchText = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            // File type filter
            _ToolbarChip(
              icon: Icons.filter_list,
              label: typeFilterActive
                  ? '${_enabledExtensions.length}/${allSupportedExtensions.length}'
                  : null,
              tooltip: 'Filter by file type',
              onTap: _showTypeFilter,
              onClear: typeFilterActive
                  ? () {
                      setState(() {
                        _enabledExtensions = Set.from(allSupportedExtensions);
                        _applyFilters();
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 4),
            // Date filter chip
            _ToolbarChip(
              icon: Icons.date_range,
              label: dateRange != null
                  ? '${dateRange!.start.month}/${dateRange!.start.day} - ${dateRange!.end.month}/${dateRange!.end.day}'
                  : null,
              tooltip: 'Filter by date range',
              onTap: _showDatePicker,
              onClear: dateRange != null ? _clearDateRange : null,
            ),
            const SizedBox(width: 4),
            // Sort button
            PopupMenuButton<String>(
              tooltip: 'Sort options',
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 15,
                      color: Colors.white70,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 4),
                      Text(
                        sortOptions.firstWhere(
                          (o) => o['value'] == sortBy,
                        )['label']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              itemBuilder: (context) => [
                ...sortOptions.map(
                  (opt) => PopupMenuItem<String>(
                    value: opt['value']!,
                    child: Row(
                      children: [
                        if (sortBy == opt['value'])
                          const Icon(Icons.check, size: 16)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(opt['label']!),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: '_toggle_dir',
                  child: Row(
                    children: [
                      Icon(
                        sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(sortAscending ? 'Ascending' : 'Descending'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: '_toggle_sections',
                  child: Row(
                    children: [
                      Icon(
                        showSectionHeaders
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text('Section headers'),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                setState(() {
                  if (val == '_toggle_dir') {
                    sortAscending = !sortAscending;
                  } else if (val == '_toggle_sections') {
                    showSectionHeaders = !showSectionHeaders;
                  } else {
                    sortBy = val;
                  }
                  _applyFilters();
                });
              },
            ),
            // Preview size slider (wide screens)
            if (isWide) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.grid_view,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              SizedBox(
                width: 90,
                child: Slider(
                  min: 80,
                  max: 280,
                  value: previewSize,
                  onChanged: (val) => setState(() => previewSize = val),
                ),
              ),
            ],
            // File count
            if (!loading)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  filteredFiles.length != mediaFiles.length
                      ? '${filteredFiles.length}/${mediaFiles.length}'
                      : '${mediaFiles.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (loading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Scanning... $_scanCount files found',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredFiles.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mediaFiles.isEmpty
                          ? 'No media files found'
                          : 'No files match your filters',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    if (mediaFiles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FilledButton.icon(
                          onPressed: _showFolderManager,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Add a folder'),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final crossAxisCount =
        (MediaQuery.of(context).size.width / (previewSize + 12)).floor().clamp(2, 12);
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 1,
    );

    if (!showSectionHeaders) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: gridDelegate,
        itemCount: filteredFiles.length,
        itemBuilder: (context, idx) => _buildGridItem(filteredFiles[idx]),
      );
    }

    final sections = _buildSections();
    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 4)),
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(section.title, section.files.length),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, idx) => _buildGridItem(section.files[idx]),
                childCount: section.files.length,
              ),
              gridDelegate: gridDelegate,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(MediaFile file) {
    final ext = p.extension(file.path).toLowerCase();
    final name = p.basename(file.path);
    final type = getMediaType(ext);

    return GestureDetector(
      onTap: () {
        if (type == MediaType.image || type == MediaType.video) {
          _openViewer(file);
        } else if (type == MediaType.audio) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InAppMediaPlayer(file: file),
            ),
          );
        } else {
          _showFileInfo(file);
        }
      },
      onLongPressStart: (details) =>
          _showContextMenu(file, details.globalPosition),
      onSecondaryTapDown: (details) =>
          _showContextMenu(file, details.globalPosition),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail content
            _buildThumbnail(file, ext, type),
            // Filename + size overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      formatFileSize(file.size),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Video play icon overlay
            if (type == MediaType.video)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            // Info button (top-right)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showFileInfo(file),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(MediaFile file, String ext, MediaType type) {
    switch (type) {
      case MediaType.image:
        return Image.file(
          File(file.path),
          fit: BoxFit.cover,
          cacheWidth: (previewSize * 2).toInt().clamp(1, 4096),
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFF1A1A2E),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white24, size: 32),
                const SizedBox(height: 4),
                Text(
                  ext.toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: Colors.white24),
                ),
              ],
            ),
          ),
        );
      case MediaType.video:
        return VideoThumbnailPreview(
          filePath: file.path,
          previewSize: previewSize,
          getThumbnail: getVideoThumbnail,
        );
      case MediaType.audio:
        return Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.music_note_rounded,
                color: Color(0xFF7C4DFF),
                size: 36,
              ),
              const SizedBox(height: 4),
              Text(
                ext.toUpperCase().replaceFirst('.', ''),
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
        );
      default:
        return Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.insert_drive_file,
                color: Colors.white24,
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                ext.toUpperCase().replaceFirst('.', ''),
                style: const TextStyle(fontSize: 10, color: Colors.white24),
              ),
            ],
          ),
        );
    }
  }
}

// --- Section data ---
class _Section {
  final String title;
  final List<MediaFile> files;
  const _Section(this.title, this.files);
}

// --- Toolbar chip widget ---
class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _ToolbarChip({
    required this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = label != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hasValue
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: hasValue
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: hasValue
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
              ),
              if (hasValue) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- Folder Manager Dialog ---
class _FolderManagerDialog extends StatefulWidget {
  final List<String> directories;
  final ValueChanged<List<String>> onSave;

  const _FolderManagerDialog({
    required this.directories,
    required this.onSave,
  });

  @override
  State<_FolderManagerDialog> createState() => _FolderManagerDialogState();
}

class _FolderManagerDialogState extends State<_FolderManagerDialog> {
  late List<String> _dirs;

  @override
  void initState() {
    super.initState();
    _dirs = List.from(widget.directories);
  }

  Future<void> _addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Add folder to gallery',
    );
    if (result != null && !_dirs.contains(result)) {
      setState(() => _dirs.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.folder_special, color: Color(0xFF7C4DFF)),
          SizedBox(width: 10),
          Text('Manage Folders', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These folders will be scanned for media files:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            if (_dirs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No folders added yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _dirs.length,
                  itemBuilder: (context, index) {
                    final dir = _dirs[index];
                    final name = p.basename(dir);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder, size: 20, color: Color(0xFF7C4DFF)),
                      title: Text(
                        name.isEmpty ? dir : name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        dir,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Remove',
                        onPressed: () => setState(() => _dirs.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: _addFolder,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Folder'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_dirs);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// --- Type Filter Dialog ---
class _TypeFilterDialog extends StatefulWidget {
  final Set<String> enabledExtensions;
  final ValueChanged<Set<String>> onSave;

  const _TypeFilterDialog({
    required this.enabledExtensions,
    required this.onSave,
  });

  @override
  State<_TypeFilterDialog> createState() => _TypeFilterDialogState();
}

class _TypeFilterDialogState extends State<_TypeFilterDialog> {
  late Set<String> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = Set.from(widget.enabledExtensions);
  }

  bool _categoryAllOn(Set<String> exts) => exts.every((e) => _enabled.contains(e));
  bool _categoryPartial(Set<String> exts) =>
      exts.any((e) => _enabled.contains(e)) && !_categoryAllOn(exts);

  void _toggleCategory(Set<String> exts) {
    setState(() {
      if (_categoryAllOn(exts)) {
        _enabled.removeAll(exts);
      } else {
        _enabled.addAll(exts);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.filter_list, color: Color(0xFF7C4DFF)),
          SizedBox(width: 10),
          Text('File Types', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick buttons
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _enabled.clear()),
                    child: const Text('None'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(
                        () => _enabled = Set.from(allSupportedExtensions)),
                    child: const Text('Default'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(
                        () => _enabled = Set.from(allSupportedExtensions)),
                    child: const Text('All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCategory('Images', imageExtensions, Icons.image),
              _buildCategory('Videos', videoExtensions, Icons.videocam),
              _buildCategory('Audio', audioExtensions, Icons.music_note),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_enabled);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildCategory(String name, Set<String> exts, IconData icon) {
    final allOn = _categoryAllOn(exts);
    final partial = _categoryPartial(exts);
    final count = exts.where((e) => _enabled.contains(e)).length;

    return ExpansionTile(
      leading: Checkbox(
        value: allOn ? true : (partial ? null : false),
        tristate: true,
        onChanged: (_) => _toggleCategory(exts),
      ),
      title: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Text('$name ($count/${exts.length})',
              style: const TextStyle(fontSize: 14)),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: exts.map((ext) {
              final on = _enabled.contains(ext);
              return FilterChip(
                label: Text(ext, style: const TextStyle(fontSize: 11)),
                selected: on,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _enabled.add(ext);
                    } else {
                      _enabled.remove(ext);
                    }
                  });
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
