import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@immutable
final class ExtractedSwatch {
  const new(this.color, this.population);

  final Color color;
  final int population;
}

/// Trích màu đại diện với bộ nhớ giới hạn cho screenshot và wallpaper.
final class PaletteExtractor {
  const new({this.sampleSize = 96, this.maximumSwatches = 8});

  final int sampleSize;
  final int maximumSwatches;

  Future<List<ExtractedSwatch>> extract(Uint8List encodedImage) async {
    if (encodedImage.isEmpty) {
      throw const FormatException('Ảnh rỗng hoặc không đọc được.');
    }
    final codec = await ui.instantiateImageCodec(
      encodedImage,
      targetWidth: sampleSize,
      targetHeight: sampleSize,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) {
        throw const FormatException('Không thể đọc điểm ảnh.');
      }
      return extractRgba(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  /// Điểm vào thuần Dart để kiểm thử thuật toán lượng tử hóa mà không cần GPU.
  @visibleForTesting
  List<ExtractedSwatch> extractRgba(Uint8List rgba) {
    if (rgba.length < 4 || rgba.length % 4 != 0) {
      throw const FormatException('Dữ liệu điểm ảnh RGBA không hợp lệ.');
    }
    final buckets = <int, _ColorBucket>{};
    for (var index = 0; index + 3 < rgba.length; index += 4) {
      final red = rgba[index];
      final green = rgba[index + 1];
      final blue = rgba[index + 2];
      final alpha = rgba[index + 3];
      if (alpha < 180) {
        continue;
      }
      final key = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4);
      buckets.putIfAbsent(key, _ColorBucket.new).add(red, green, blue);
    }
    if (buckets.isEmpty) {
      throw const FormatException('Ảnh không có màu hiển thị hợp lệ.');
    }

    final ranked = buckets.values.toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    final selected = <ExtractedSwatch>[];
    for (final bucket in ranked) {
      final color = bucket.color;
      if (selected.any(
        (item) => _distanceSquared(item.color, color) < 42 * 42,
      )) {
        continue;
      }
      selected.add(ExtractedSwatch(color, bucket.count));
      if (selected.length == maximumSwatches) {
        break;
      }
    }

    if (selected.length == 1) {
      final base = HSLColor.fromColor(selected.single.color);
      selected.add(
        ExtractedSwatch(
          base
              .withHue((base.hue + 150) % 360)
              .withSaturation((base.saturation + 0.35).clamp(0.35, 0.9))
              .withLightness(base.lightness < 0.5 ? 0.62 : 0.38)
              .toColor(),
          1,
        ),
      );
    }
    return selected;
  }

  static double _distanceSquared(Color first, Color second) {
    final a = first.toARGB32();
    final b = second.toARGB32();
    final dr = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF);
    final dg = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF);
    final db = (a & 0xFF) - (b & 0xFF);
    return (dr * dr + dg * dg + db * db).toDouble();
  }
}

final class _ColorBucket {
  int count = 0;
  int red = 0;
  int green = 0;
  int blue = 0;

  void add(int r, int g, int b) {
    count += 1;
    red += r;
    green += g;
    blue += b;
  }

  Color get color => Color.fromARGB(
    255,
    (red / count).round(),
    (green / count).round(),
    (blue / count).round(),
  );

  double get score {
    final hsl = HSLColor.fromColor(color);
    final chromaBoost = 0.55 + hsl.saturation;
    final usefulLuminance = 1 - ((hsl.lightness - 0.5).abs() * 0.55);
    return count * chromaBoost * usefulLuminance;
  }
}
