import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class MediaFile {
  final String path;
  final FileSystemEntityType type;
  final int size;
  final DateTime modified;

  MediaFile({
    required this.path,
    required this.type,
    required this.size,
    required this.modified,
  });
}

class MediaGallery extends StatefulWidget {
  final String directory;
  const MediaGallery({super.key, required this.directory});

  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  List<MediaFile> mediaFiles = [];
  List<MediaFile> filteredFiles = [];
  bool loading = true;
  String sortBy = 'date';
  static const sortOptions = [
    {'label': 'Date', 'value': 'date'},
    {'label': 'Size', 'value': 'size'},
  ];
  String searchText = '';
  DateTimeRange? dateRange;

  static const supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.wmv',
    '.flv',
    '.heic',
    '.tiff',
    '.svg',
    '.mpg',
    '.mpeg',
    '.3gp',
    '.m4v',
    '.ogg',
    '.ogv',
    '.mp3',
    '.wav',
    '.aac',
    '.flac',
    '.midi',
    '.mid',
    '.opus',
    '.amr',
    '.aiff',
    '.ape',
    '.wv',
    '.mka',
    '.m3u8',
    '.ts',
    '.vob',
    '.rm',
    '.rmvb',
    '.asf',
    '.f4v',
    '.m2ts',
    '.mts',
    '.divx',
    '.xvid',
    '.mxf',
    '.mpg2',
    '.mpv',
    '.mpe',
    '.mpv2',
    '.m2v',
    '.m1v',
    '.3g2',
    '.3gp2',
    '.3gpp',
    '.3gpp2',
    '.m2p',
    '.m2t',
    '.m2v',
    '.m4p',
    '.m4b',
    '.m4r',
    '.m4a',
    '.m4v',
    '.mkv',
    '.mod',
    '.mov',
    '.mp2',
    '.mp2v',
    '.mp4',
    '.mp4v',
    '.mpe',
    '.mpeg',
    '.mpg',
    '.mpv2',
    '.mts',
    '.ogg',
    '.ogm',
    '.ogv',
    '.qt',
    '.tod',
    '.ts',
    '.tts',
    '.vob',
    '.vro',
    '.webm',
    '.wmv',
    '.wtv',
    '.xesc',
    '.yuv',
    '.aac',
    '.ac3',
    '.aiff',
    '.alac',
    '.amr',
    '.ape',
    '.au',
    '.dts',
    '.flac',
    '.m4a',
    '.m4b',
    '.m4p',
    '.mid',
    '.midi',
    '.mp3',
    '.mpa',
    '.mpc',
    '.oga',
    '.ogg',
    '.opus',
    '.ra',
    '.ram',
    '.spx',
    '.tta',
    '.wav',
    '.wma',
    '.wv',
    '.webm',
    '.caf',
    '.dsf',
    '.dff',
    '.wv',
    '.aif',
    '.aifc',
    '.mogg',
    '.mpc',
    '.mp+',
    '.ofr',
    '.ofs',
    '.psf',
    '.psf2',
    '.tak',
    '.tta',
    '.w64',
    '.wv',
    '.xm',
    '.it',
    '.s3m',
    '.mod',
    '.mtm',
    '.umx',
    '.mo3',
    '.abc',
    '.kar',
    '.mml',
    '.nbs',
    '.ptb',
    '.rmi',
    '.sng',
    '.ult',
    '.vce',
    '.vmf',
    '.xg',
    '.zpl',
    '.zpl2',
    '.zpl3',
    '.zpl4',
    '.zpl5',
    '.zpl6',
    '.zpl7',
    '.zpl8',
    '.zpl9',
    '.zpl10',
    '.zpl11',
    '.zpl12',
    '.zpl13',
    '.zpl14',
    '.zpl15',
    '.zpl16',
    '.zpl17',
    '.zpl18',
    '.zpl19',
    '.zpl20',
    '.zpl21',
    '.zpl22',
    '.zpl23',
    '.zpl24',
    '.zpl25',
    '.zpl26',
    '.zpl27',
    '.zpl28',
    '.zpl29',
    '.zpl30',
    '.zpl31',
    '.zpl32',
    '.zpl33',
    '.zpl34',
    '.zpl35',
    '.zpl36',
    '.zpl37',
    '.zpl38',
    '.zpl39',
    '.zpl40',
    '.zpl41',
    '.zpl42',
    '.zpl43',
    '.zpl44',
    '.zpl45',
    '.zpl46',
    '.zpl47',
    '.zpl48',
    '.zpl49',
    '.zpl50',
    '.zpl51',
    '.zpl52',
    '.zpl53',
    '.zpl54',
    '.zpl55',
    '.zpl56',
    '.zpl57',
    '.zpl58',
    '.zpl59',
    '.zpl60',
    '.zpl61',
    '.zpl62',
    '.zpl63',
    '.zpl64',
    '.zpl65',
    '.zpl66',
    '.zpl67',
    '.zpl68',
    '.zpl69',
    '.zpl70',
    '.zpl71',
    '.zpl72',
    '.zpl73',
    '.zpl74',
    '.zpl75',
    '.zpl76',
    '.zpl77',
    '.zpl78',
    '.zpl79',
    '.zpl80',
    '.zpl81',
    '.zpl82',
    '.zpl83',
    '.zpl84',
    '.zpl85',
    '.zpl86',
    '.zpl87',
    '.zpl88',
    '.zpl89',
    '.zpl90',
    '.zpl91',
    '.zpl92',
    '.zpl93',
    '.zpl94',
    '.zpl95',
    '.zpl96',
    '.zpl97',
    '.zpl98',
    '.zpl99',
    '.zpl100',
  ];

  @override
  void initState() {
    super.initState();
    _scanMediaFiles();
  }

  Future<void> _scanMediaFiles() async {
    setState(() => loading = true);
    final dir = Directory(widget.directory);
    final files = <MediaFile>[];
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (supportedExtensions.contains(ext)) {
          final stat = await entity.stat();
          files.add(
            MediaFile(
              path: entity.path,
              type: stat.type,
              size: stat.size,
              modified: stat.modified,
            ),
          );
        }
      }
    }
    _sortFiles(files);
    setState(() {
      mediaFiles = files;
      _applyFilters();
      loading = false;
    });
  }

  void _applyFilters() {
    filteredFiles = mediaFiles.where((file) {
      final matchesText =
          searchText.isEmpty ||
          p
              .basename(file.path)
              .toLowerCase()
              .contains(searchText.toLowerCase());
      final matchesDate =
          dateRange == null ||
          (file.modified.isAfter(
                dateRange!.start.subtract(const Duration(days: 1)),
              ) &&
              file.modified.isBefore(
                dateRange!.end.add(const Duration(days: 1)),
              ));
      return matchesText && matchesDate;
    }).toList();
    _sortFiles(filteredFiles);
  }

  void _sortFiles(List<MediaFile> files) {
    if (sortBy == 'size') {
      files.sort((a, b) => b.size.compareTo(a.size));
    } else {
      files.sort((a, b) => b.modified.compareTo(a.modified));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (mediaFiles.isEmpty) {
      return const Center(child: Text('No media files found.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    setState(() {
                      searchText = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  dateRange == null
                      ? 'Pick date range'
                      : '${dateRange!.start.year}/${dateRange!.start.month}/${dateRange!.start.day} - ${dateRange!.end.year}/${dateRange!.end.month}/${dateRange!.end.day}',
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1970),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() {
                      dateRange = picked;
                      _applyFilters();
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              const Text('Sort by: '),
              DropdownButton<String>(
                value: sortBy,
                items: sortOptions
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt['value']!,
                        child: Text(opt['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      sortBy = val;
                      _applyFilters();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: filteredFiles.length,
            itemBuilder: (context, index) {
              final file = filteredFiles[index];
              final ext = p.extension(file.path).toLowerCase();
              if ([
                ".jpg",
                ".jpeg",
                ".png",
                ".gif",
                ".bmp",
                ".webp",
                ".heic",
                ".tiff",
                ".svg",
              ].contains(ext)) {
                return Image.file(File(file.path), fit: BoxFit.cover);
              } else if ([
                ".mp4",
                ".mov",
                ".avi",
                ".mkv",
                ".webm",
                ".wmv",
                ".flv",
                ".mpg",
                ".mpeg",
                ".3gp",
                ".m4v",
                ".ogg",
                ".ogv",
              ].contains(ext)) {
                return Container(
                  color: Colors.black26,
                  child: const Center(child: Icon(Icons.videocam, size: 48)),
                );
              } else {
                return Container(
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(Icons.insert_drive_file, size: 32),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
