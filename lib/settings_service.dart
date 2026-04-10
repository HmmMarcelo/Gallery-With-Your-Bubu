import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

const String appVersion = '1.0.0';

class AppSettings {
  List<String> directories;
  String? backgroundColorHex;
  String? backgroundImagePath;

  AppSettings({
    List<String>? directories,
    this.backgroundColorHex,
    this.backgroundImagePath,
  }) : directories = directories ?? [];

  Map<String, dynamic> toJson() => {
    'directories': directories,
    if (backgroundColorHex != null) 'backgroundColorHex': backgroundColorHex,
    if (backgroundImagePath != null) 'backgroundImagePath': backgroundImagePath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    directories: (json['directories'] as List<dynamic>?)?.cast<String>() ?? [],
    backgroundColorHex: json['backgroundColorHex'] as String?,
    backgroundImagePath: json['backgroundImagePath'] as String?,
  );

  static String get _settingsDir {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) return p.join(appData, 'GalleryWithYourBubu');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        return p.join(
          home,
          'Library',
          'Application Support',
          'GalleryWithYourBubu',
        );
      }
    }
    final home = Platform.environment['HOME'];
    if (home != null) return p.join(home, '.config', 'GalleryWithYourBubu');
    return '.';
  }

  static String get settingsPath => p.join(_settingsDir, 'settings.json');

  static Future<AppSettings> load() async {
    try {
      final file = File(settingsPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return AppSettings.fromJson(jsonDecode(content));
      }
    } catch (_) {}
    return AppSettings();
  }

  Future<void> save() async {
    try {
      final dir = Directory(_settingsDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(
        settingsPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()));
    } catch (_) {}
  }
}
