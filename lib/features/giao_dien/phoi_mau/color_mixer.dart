import 'package:better_phenikaa_schedule/features/giao_dien/bang_mau_anh/palette_extractor.dart';
import 'package:flutter/material.dart';

final class ColorMixer {
  const new();

  List<ExtractedSwatch> mix(List<Color> colors, List<double> weights) {
    if (colors.length < 2 || colors.length > 3) {
      throw ArgumentError('Cần chọn từ 2 đến 3 màu.');
    }
    final safeWeights = List<double>.generate(
      colors.length,
      (index) => index < weights.length ? weights[index].clamp(0.0, 100.0) : 1,
    );
    var total = safeWeights.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      total = colors.length.toDouble();
      for (var index = 0; index < safeWeights.length; index += 1) {
        safeWeights[index] = 1;
      }
    }

    int channel(int shift) {
      var value = 0.0;
      for (var index = 0; index < colors.length; index += 1) {
        final argb = colors[index].toARGB32();
        value += ((argb >> shift) & 0xFF) * safeWeights[index] / total;
      }
      return value.round().clamp(0, 255);
    }

    final blended = Color.fromARGB(255, channel(16), channel(8), channel(0));
    final result = <ExtractedSwatch>[
      ExtractedSwatch(blended, 1000),
      for (var index = 0; index < colors.length; index += 1)
        ExtractedSwatch(colors[index], (safeWeights[index] * 10).round()),
    ];
    final hsl = HSLColor.fromColor(blended);
    result.add(
      ExtractedSwatch(
        hsl
            .withHue((hsl.hue + 145) % 360)
            .withSaturation((hsl.saturation + 0.25).clamp(0.35, 0.9))
            .toColor(),
        1,
      ),
    );
    return result;
  }
}
