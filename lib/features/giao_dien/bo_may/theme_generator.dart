import 'dart:math' as math;

import 'package:better_phenikaa_schedule/features/giao_dien/bang_mau_anh/palette_extractor.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_tokens.dart';
import 'package:flutter/material.dart';

@immutable
final class ThemeGenerationSettings {
  const new({this.preferDark, this.radius = 16});

  final bool? preferDark;
  final double radius;
}

/// Assigns semantic roles by luminance, chroma and hue separation.
final class ThemeGenerator {
  const new();

  ThemeTokens generate(
    List<ExtractedSwatch> source, {
    ThemeGenerationSettings settings = const ThemeGenerationSettings(),
  }) {
    if (source.isEmpty) {
      throw ArgumentError('Bảng màu không được rỗng.');
    }
    final swatches = source.toList()
      ..sort((left, right) => right.population.compareTo(left.population));
    final population = swatches.fold<int>(
      0,
      (sum, item) => sum + item.population,
    );
    final averageLuminance =
        swatches.fold<double>(0, (sum, item) {
          return sum + (item.color.computeLuminance() * item.population);
        }) /
        math.max(1, population);
    final dark = settings.preferDark ?? averageLuminance < 0.42;

    final colorful = swatches.toList()
      ..sort((left, right) {
        final a = HSLColor.fromColor(left.color).saturation;
        final b = HSLColor.fromColor(right.color).saturation;
        return b.compareTo(a);
      });
    final primary = _normalizeAccent(colorful.first.color, dark: dark);
    final accent = _mostDistinct(primary, colorful.map((item) => item.color));
    final secondary = mixColors(primary, accent, 0.38);

    final dominant = swatches.first.color;
    final neutralAnchor = HSLColor.fromColor(dominant)
        .withSaturation(math.min(HSLColor.fromColor(dominant).saturation, 0.18))
        .toColor();
    final background = dark
        ? _setLightness(neutralAnchor, 0.055)
        : _setLightness(neutralAnchor, 0.975);
    final backgroundEnd = dark
        ? mixColors(background, primary, 0.13)
        : mixColors(background, primary, 0.055);
    final surface = dark
        ? mixColors(background, Colors.white, 0.055)
        : mixColors(background, Colors.black, 0.018);
    final card = dark
        ? mixColors(surface, Colors.white, 0.045)
        : mixColors(surface, Colors.white, 0.72);
    final cardAlternate = mixColors(card, primary, dark ? 0.13 : 0.075);
    final textPrimary = _readableOn(background, minimumRatio: 7);
    final textSecondary = _ensureContrast(
      mixColors(textPrimary, background, 0.34),
      background,
      minimumRatio: 4.5,
    );
    final border = _ensureContrast(
      mixColors(background, textPrimary, dark ? 0.20 : 0.11),
      background,
      minimumRatio: 1.35,
    );

    final widgetStartCandidate = dark
        ? mixColors(background, primary, 0.46)
        : _setLightness(primary, 0.34);
    final widgetEndCandidate = dark
        ? mixColors(backgroundEnd, accent, 0.42)
        : _setLightness(mixColors(primary, accent, 0.42), 0.44);
    final widgetText = _readableAcross(
      widgetStartCandidate,
      widgetEndCandidate,
      minimumRatio: 4.5,
    );
    final widgetStart = _ensureBackgroundContrast(
      widgetStartCandidate,
      widgetText,
      minimumRatio: 4.5,
    );
    final widgetEnd = _ensureBackgroundContrast(
      widgetEndCandidate,
      widgetText,
      minimumRatio: 4.5,
    );
    final widgetSubtext = _ensureAcross(
      mixColors(widgetText, widgetEnd, 0.22),
      widgetStart,
      widgetEnd,
      minimumRatio: 3,
    );

    return ThemeTokens(
      background: background,
      backgroundEnd: backgroundEnd,
      surface: surface,
      card: card,
      cardAlternate: cardAlternate,
      primary: _ensureContrast(primary, background, minimumRatio: 3),
      secondary: _ensureContrast(secondary, background, minimumRatio: 2.3),
      accent: _ensureContrast(accent, background, minimumRatio: 3),
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      icon: textPrimary,
      border: border,
      divider: border,
      selected: mixColors(card, primary, dark ? 0.28 : 0.14),
      pressed: mixColors(primary, textPrimary, dark ? 0.20 : 0.12),
      disabled: mixColors(textSecondary, background, 0.42),
      success: _statusColor(const Color(0xFF1B9E57), background),
      warning: _statusColor(const Color(0xFFE08A00), background),
      error: _statusColor(const Color(0xFFD83B45), background),
      widgetStart: widgetStart,
      widgetEnd: widgetEnd,
      widgetText: widgetText,
      widgetSubtext: widgetSubtext,
      shadow: dark ? const Color(0x78000000) : const Color(0x24000000),
      dark: dark,
      radius: settings.radius.clamp(0.0, 28.0),
    );
  }

  static Color _normalizeAccent(Color color, {required bool dark}) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.42, 0.92))
        .withLightness(
          hsl.lightness.clamp(dark ? 0.54 : 0.32, dark ? 0.72 : 0.58),
        )
        .toColor();
  }

  static Color _mostDistinct(Color origin, Iterable<Color> candidates) {
    final base = HSLColor.fromColor(origin);
    var best = origin;
    var bestScore = -1.0;
    for (final candidate in candidates) {
      final hsl = HSLColor.fromColor(candidate);
      final rawHue = (hsl.hue - base.hue).abs();
      final hueDistance = math.min(rawHue, 360 - rawHue) / 180;
      final score = hueDistance + (hsl.saturation * 0.45);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    if (bestScore < 0.35) {
      return base
          .withHue((base.hue + 145) % 360)
          .withSaturation(math.max(0.5, base.saturation))
          .toColor();
    }
    return best;
  }

  static Color _setLightness(Color color, double lightness) =>
      HSLColor.fromColor(color)
          .withLightness(lightness.clamp(0.0, 1.0))
          .toColor();

  static Color _readableOn(Color background, {required double minimumRatio}) {
    final black = contrastRatio(Colors.black, background);
    final white = contrastRatio(Colors.white, background);
    final chosen = black >= white ? Colors.black : Colors.white;
    return _ensureContrast(chosen, background, minimumRatio: minimumRatio);
  }

  static Color _readableAcross(
    Color first,
    Color second, {
    required double minimumRatio,
  }) {
    final blackScore = math.min(
      contrastRatio(Colors.black, first),
      contrastRatio(Colors.black, second),
    );
    final whiteScore = math.min(
      contrastRatio(Colors.white, first),
      contrastRatio(Colors.white, second),
    );
    final chosen = blackScore >= whiteScore ? Colors.black : Colors.white;
    return _ensureAcross(chosen, first, second, minimumRatio: minimumRatio);
  }

  static Color _ensureAcross(
    Color foreground,
    Color first,
    Color second, {
    required double minimumRatio,
  }) {
    if (contrastRatio(foreground, first) >= minimumRatio &&
        contrastRatio(foreground, second) >= minimumRatio) {
      return foreground;
    }
    final blackScore = math.min(
      contrastRatio(Colors.black, first),
      contrastRatio(Colors.black, second),
    );
    final whiteScore = math.min(
      contrastRatio(Colors.white, first),
      contrastRatio(Colors.white, second),
    );
    return blackScore >= whiteScore ? Colors.black : Colors.white;
  }

  static Color _ensureContrast(
    Color foreground,
    Color background, {
    required double minimumRatio,
  }) {
    if (contrastRatio(foreground, background) >= minimumRatio) {
      return foreground;
    }
    final target = background.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    var candidate = foreground;
    for (var step = 1; step <= 20; step += 1) {
      candidate = mixColors(foreground, target, step / 20);
      if (contrastRatio(candidate, background) >= minimumRatio) {
        return candidate;
      }
    }
    return target;
  }

  static Color _ensureBackgroundContrast(
    Color background,
    Color foreground, {
    required double minimumRatio,
  }) {
    if (contrastRatio(foreground, background) >= minimumRatio) {
      return background;
    }
    final target = foreground.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    for (var step = 1; step <= 20; step += 1) {
      final candidate = mixColors(background, target, step / 20);
      if (contrastRatio(foreground, candidate) >= minimumRatio) {
        return candidate;
      }
    }
    return target;
  }

  static Color _statusColor(Color preferred, Color background) =>
      _ensureContrast(preferred, background, minimumRatio: 3);
}
