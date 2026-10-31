import 'package:flutter/material.dart';

/// Nguồn đầu vào độc lập với cách sinh token màu.
enum ThemeSourceKind { image, colorMix }

@immutable
final class ThemeSourceData {
  const new image({required this.imagePath, required this.colors})
    : kind = ThemeSourceKind.image,
      weights = const <double>[];

  const new colorMix({required this.colors, required this.weights})
    : kind = ThemeSourceKind.colorMix,
      imagePath = null;

  factory fromJson(Map<String, Object?> json) {
    final kindName = json['kind'] as String?;
    final rawColors = json['colors'] as List<Object?>? ?? const <Object?>[];
    final colors = rawColors
        .whereType<num>()
        .map((value) => Color(value.toInt()))
        .toList(growable: false);
    if (kindName == ThemeSourceKind.image.name) {
      return ThemeSourceData.image(
        imagePath: json['imagePath'] as String?,
        colors: colors,
      );
    }
    final rawWeights = json['weights'] as List<Object?>? ?? const <Object?>[];
    return ThemeSourceData.colorMix(
      colors: colors,
      weights: rawWeights
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false),
    );
  }

  final ThemeSourceKind kind;
  final String? imagePath;
  final List<Color> colors;
  final List<double> weights;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'imagePath': imagePath,
    'colors': colors.map((color) => color.toARGB32()).toList(),
    'weights': weights,
  };
}
