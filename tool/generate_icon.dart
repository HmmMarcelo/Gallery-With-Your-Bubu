// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  // Generate icon at 512x512 (will be used as source for all sizes)
  final icon = generateIcon(512);

  // Save as PNG for Android
  final androidDirs = {
    'android/app/src/main/res/mipmap-mdpi': 48,
    'android/app/src/main/res/mipmap-hdpi': 72,
    'android/app/src/main/res/mipmap-xhdpi': 96,
    'android/app/src/main/res/mipmap-xxhdpi': 144,
    'android/app/src/main/res/mipmap-xxxhdpi': 192,
  };

  for (final entry in androidDirs.entries) {
    final dir = Directory(entry.key);
    if (dir.existsSync()) {
      final resized = img.copyResize(
        icon,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic,
      );
      File(
        '${entry.key}/ic_launcher.png',
      ).writeAsBytesSync(img.encodePng(resized));
      print('Wrote ${entry.key}/ic_launcher.png');
    }
  }

  // Save as ICO for Windows (256x256 PNG inside ICO)
  final ico256 = img.copyResize(
    icon,
    width: 256,
    height: 256,
    interpolation: img.Interpolation.cubic,
  );
  final icoBytes = _createIco(ico256);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(icoBytes);
  print('Wrote windows/runner/resources/app_icon.ico');

  // Also save a 512 version as web icon
  File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon));
  final icon192 = img.copyResize(
    icon,
    width: 192,
    height: 192,
    interpolation: img.Interpolation.cubic,
  );
  File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));
  print('Wrote web icons');

  print('Done!');
}

img.Image generateIcon(int size) {
  final image = img.Image(width: size, height: size);

  // Background: deep purple gradient
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final t = y / size;
      final r = _lerp(30, 18, t).round();
      final g = _lerp(15, 10, t).round();
      final b = _lerp(60, 40, t).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Draw a rounded rectangle background
  _fillRoundedRect(image, 0, 0, size, size, size ~/ 5, (x, y) {
    final t = y / size;
    final r = _lerp(45, 25, t).round();
    final g = _lerp(20, 12, t).round();
    final b = _lerp(90, 55, t).round();
    return img.ColorFloat32.rgba(r / 255, g / 255, b / 255, 1.0);
  });

  // Draw a stylized mountain/landscape scene (gallery icon feel)
  final cx = size / 2;
  final cy = size / 2;

  // Large mountain (left)
  _fillTriangle(
    image,
    (size * 0.12).round(),
    (size * 0.72).round(),
    (size * 0.42).round(),
    (size * 0.25).round(),
    (size * 0.65).round(),
    (size * 0.72).round(),
    img.ColorFloat32.rgba(124 / 255, 77 / 255, 255 / 255, 0.9),
  );

  // Small mountain (right)
  _fillTriangle(
    image,
    (size * 0.45).round(),
    (size * 0.72).round(),
    (size * 0.68).round(),
    (size * 0.38).round(),
    (size * 0.88).round(),
    (size * 0.72).round(),
    img.ColorFloat32.rgba(179 / 255, 136 / 255, 255 / 255, 0.85),
  );

  // Sun circle (top right)
  final sunX = (size * 0.72).round();
  final sunY = (size * 0.22).round();
  final sunR = (size * 0.08).round();
  _fillCircle(
    image,
    sunX,
    sunY,
    sunR,
    img.ColorFloat32.rgba(255 / 255, 183 / 255, 77 / 255, 0.95),
  );

  // Bottom bar (ground)
  for (int y = (size * 0.72).round(); y < (size * 0.82).round(); y++) {
    for (int x = (size * 0.1).round(); x < (size * 0.9).round(); x++) {
      if (_isInsideRoundedRect(
        x,
        y,
        (size * 0.1).round(),
        (size * 0.72).round(),
        (size * 0.8).round(),
        (size * 0.1).round(),
        (size * 0.03).round(),
      )) {
        image.setPixelRgba(x, y, 50, 30, 100, 200);
      }
    }
  }

  // Heart shape in the center-bottom (the "Bubu" touch)
  _drawHeart(
    image,
    (size * 0.5).round(),
    (size * 0.88).round(),
    (size * 0.06).round(),
    img.ColorFloat32.rgba(255 / 255, 100 / 255, 130 / 255, 0.95),
  );

  return image;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

void _fillCircle(img.Image image, int cx, int cy, int radius, img.Color color) {
  final r2 = radius * radius;
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= r2) {
          _blendPixel(image, x, y, color);
        }
      }
    }
  }
}

void _fillTriangle(
  img.Image image,
  int x0,
  int y0,
  int x1,
  int y1,
  int x2,
  int y2,
  img.Color color,
) {
  final minX = [x0, x1, x2].reduce(min).clamp(0, image.width - 1);
  final maxX = [x0, x1, x2].reduce(max).clamp(0, image.width - 1);
  final minY = [y0, y1, y2].reduce(min).clamp(0, image.height - 1);
  final maxY = [y0, y1, y2].reduce(max).clamp(0, image.height - 1);

  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (_pointInTriangle(x, y, x0, y0, x1, y1, x2, y2)) {
        _blendPixel(image, x, y, color);
      }
    }
  }
}

bool _pointInTriangle(
  int px,
  int py,
  int x0,
  int y0,
  int x1,
  int y1,
  int x2,
  int y2,
) {
  final d1 = _sign(px, py, x0, y0, x1, y1);
  final d2 = _sign(px, py, x1, y1, x2, y2);
  final d3 = _sign(px, py, x2, y2, x0, y0);
  final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
  final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
  return !(hasNeg && hasPos);
}

double _sign(int x1, int y1, int x2, int y2, int x3, int y3) {
  return (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3) + 0.0;
}

void _blendPixel(img.Image image, int x, int y, img.Color color) {
  final a = color.a;
  if (a <= 0) return;
  if (a >= 1.0) {
    image.setPixelRgba(
      x,
      y,
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      255,
    );
    return;
  }
  final existing = image.getPixel(x, y);
  final er = existing.r / 255.0;
  final eg = existing.g / 255.0;
  final eb = existing.b / 255.0;
  final nr = er * (1 - a) + color.r * a;
  final ng = eg * (1 - a) + color.g * a;
  final nb = eb * (1 - a) + color.b * a;
  image.setPixelRgba(
    x,
    y,
    (nr * 255).round(),
    (ng * 255).round(),
    (nb * 255).round(),
    255,
  );
}

void _fillRoundedRect(
  img.Image image,
  int x,
  int y,
  int w,
  int h,
  int radius,
  img.Color Function(int x, int y) colorFn,
) {
  for (int py = y; py < y + h; py++) {
    for (int px = x; px < x + w; px++) {
      if (_isInsideRoundedRect(px, py, x, y, w, h, radius)) {
        final c = colorFn(px, py);
        _blendPixel(image, px, py, c);
      }
    }
  }
}

bool _isInsideRoundedRect(
  int px,
  int py,
  int x,
  int y,
  int w,
  int h,
  int radius,
) {
  if (px < x || px >= x + w || py < y || py >= y + h) return false;
  // Check corners
  if (px < x + radius && py < y + radius) {
    return _dist(px, py, x + radius, y + radius) <= radius;
  }
  if (px >= x + w - radius && py < y + radius) {
    return _dist(px, py, x + w - radius, y + radius) <= radius;
  }
  if (px < x + radius && py >= y + h - radius) {
    return _dist(px, py, x + radius, y + h - radius) <= radius;
  }
  if (px >= x + w - radius && py >= y + h - radius) {
    return _dist(px, py, x + w - radius, y + h - radius) <= radius;
  }
  return true;
}

double _dist(int x1, int y1, int x2, int y2) {
  final dx = (x1 - x2).toDouble();
  final dy = (y1 - y2).toDouble();
  return sqrt(dx * dx + dy * dy);
}

void _drawHeart(img.Image image, int cx, int cy, int size, img.Color color) {
  for (int y = -size; y <= size; y++) {
    for (int x = -size * 2; x <= size * 2; x++) {
      final nx = x / size.toDouble();
      final ny = y / size.toDouble();
      // Heart equation: (x^2 + y^2 - 1)^3 - x^2*y^3 <= 0
      final v = pow(nx * nx + ny * ny - 1, 3) - nx * nx * ny * ny * ny;
      if (v <= 0) {
        final px = cx + x;
        final py = cy - y; // flip y
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          _blendPixel(image, px, py, color);
        }
      }
    }
  }
}

// Create a minimal ICO file with one 256x256 PNG image
List<int> _createIco(img.Image image) {
  final pngBytes = img.encodePng(image);
  final header = <int>[
    0, 0, // reserved
    1, 0, // ICO type
    1, 0, // 1 image
  ];
  final dirEntry = <int>[
    0, // width (0 = 256)
    0, // height (0 = 256)
    0, // color palette
    0, // reserved
    1, 0, // color planes
    32, 0, // bits per pixel
    ...(_intToBytes4(pngBytes.length)),
    ...(_intToBytes4(6 + 16)), // offset = header(6) + dirEntry(16)
  ];
  return [...header, ...dirEntry, ...pngBytes];
}

List<int> _intToBytes4(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}
