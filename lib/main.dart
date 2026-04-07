import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';
import 'media_gallery.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const BubuGalleryApp());
}

class BubuGalleryApp extends StatelessWidget {
  const BubuGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallery With Your Bubu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: MediaGallery(initialDirectories: [_getDefaultDirectory()]),
    );
  }

  static String _getDefaultDirectory() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) return '$userProfile\\Pictures';
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) return '$home/Pictures';
    } else if (Platform.isAndroid) {
      return '/storage/emulated/0/DCIM';
    }
    return '.';
  }
}
