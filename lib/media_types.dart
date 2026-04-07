import 'dart:io';

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

enum MediaType { image, video, audio, unknown }

const Set<String> imageExtensions = {
  '.jpg', '.jpeg', '.jfif', '.png', '.gif', '.bmp', '.webp',
  '.heic', '.heif', '.tiff', '.tif', '.ico', '.avif',
  // RAW formats
  '.raw', '.cr2', '.cr3', '.nef', '.arw', '.dng', '.orf',
  '.rw2', '.pef', '.srw', '.raf', '.rwl', '.3fr', '.kdc',
  '.mrw', '.nrw', '.x3f', '.srf',
};

const Set<String> videoExtensions = {
  '.mp4',
  '.mov',
  '.avi',
  '.mkv',
  '.webm',
  '.wmv',
  '.flv',
  '.3gp',
  '.3g2',
  '.m4v',
  '.mpg',
  '.mpeg',
  '.ogv',
  '.ts',
  '.vob',
  '.m2ts',
  '.mts',
  '.mxf',
  '.asf',
  '.f4v',
  '.divx',
  '.m2v',
  '.m1v',
  '.qt',
  '.tod',
  '.vro',
  '.wtv',
  '.rm',
  '.rmvb',
  '.mp4v',
  '.m2p',
  '.m2t',
  '.mod',
  '.ogm',
};

const Set<String> audioExtensions = {
  '.mp3',
  '.wav',
  '.aac',
  '.flac',
  '.ogg',
  '.opus',
  '.m4a',
  '.wma',
  '.alac',
  '.aiff',
  '.aif',
  '.ape',
  '.wv',
  '.dts',
  '.ac3',
  '.mid',
  '.midi',
  '.mka',
  '.pcm',
  '.amr',
  '.caf',
  '.dsf',
  '.dff',
  '.oga',
  '.spx',
  '.tta',
  '.weba',
  '.m4b',
};

Set<String> get allSupportedExtensions => {
  ...imageExtensions,
  ...videoExtensions,
  ...audioExtensions,
};

MediaType getMediaType(String extension) {
  if (imageExtensions.contains(extension)) return MediaType.image;
  if (videoExtensions.contains(extension)) return MediaType.video;
  if (audioExtensions.contains(extension)) return MediaType.audio;
  return MediaType.unknown;
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}  '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

Future<void> openFileLocation(String filePath) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', ['/select,', filePath]);
  } else if (Platform.isMacOS) {
    await Process.run('open', ['-R', filePath]);
  } else if (Platform.isLinux) {
    final dir = filePath.substring(0, filePath.lastIndexOf('/'));
    await Process.run('xdg-open', [dir]);
  }
}

Future<void> openFileExternal(String filePath) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', filePath]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [filePath]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [filePath]);
  }
}
