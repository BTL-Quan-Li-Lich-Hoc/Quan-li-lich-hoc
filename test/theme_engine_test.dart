import 'dart:typed_data';

import 'package:better_phenikaa_schedule/features/giao_dien/bang_mau_anh/palette_extractor.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_generator.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_tokens.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phoi_mau/color_mixer.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mixer = ColorMixer();
  const generator = ThemeGenerator();

  group('Theme Engine', () {
    for (final colors in <List<Color>>[
      const <Color>[Color(0xFFFDFDFD), Color(0xFFF7F7F7), Color(0xFFFFFFFF)],
      const <Color>[Color(0xFF050505), Color(0xFF111111), Color(0xFF181818)],
      const <Color>[Color(0xFF1747B5), Color(0xFF1848B6), Color(0xFF1949B7)],
    ]) {
      test('sinh token đọc được với palette biên', () {
        final tokens = generator.generate(
          mixer.mix(colors, <double>[60, 30, 10]),
        );
        expect(
          contrastRatio(tokens.textPrimary, tokens.background),
          greaterThanOrEqualTo(7),
        );
        expect(
          contrastRatio(tokens.textSecondary, tokens.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.widgetText, tokens.widgetStart),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.widgetText, tokens.widgetEnd),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('tỷ lệ bằng không vẫn tạo palette ổn định', () {
      final swatches = mixer.mix(
        const <Color>[Colors.red, Colors.green, Colors.blue],
        const <double>[0, 0, 0],
      );
      expect(swatches, hasLength(5));
      expect(generator.generate(swatches).primary, isA<Color>());
    });

    test('token lưu local có thể khôi phục đầy đủ', () {
      final source = generator.generate(
        mixer.mix(
          const <Color>[Color(0xFF0057B8), Color(0xFFFFD700)],
          const <double>[65, 35],
        ),
      );
      final restored = ThemeTokens.fromJson(source.toJson());
      expect(restored.toJson(), source.toJson());
    });

    test('ảnh gần đơn sắc vẫn sinh ít nhất hai swatch', () {
      final bytes = Uint8List(32 * 32 * 4);
      for (var index = 0; index < bytes.length; index += 4) {
        bytes[index] = 0x24;
        bytes[index + 1] = 0x56;
        bytes[index + 2] = 0xA6;
        bytes[index + 3] = 0xFF;
      }
      final swatches = const PaletteExtractor().extractRgba(bytes);
      expect(swatches.length, greaterThanOrEqualTo(2));
    });
  });

  group('Font Engine', () {
    test('từ chối font hỏng', () {
      expect(
        () => ThemeFontManager.validateFontBytes(Uint8List(32)),
        throwsFormatException,
      );
    });

    test('chấp nhận header TTF và OTF', () {
      final ttf = Uint8List(12)..setAll(0, <int>[0, 1, 0, 0]);
      final otf = Uint8List(12)..setAll(0, 'OTTO'.codeUnits);
      expect(() => ThemeFontManager.validateFontBytes(ttf), returnsNormally);
      expect(() => ThemeFontManager.validateFontBytes(otf), returnsNormally);
    });
  });
}
