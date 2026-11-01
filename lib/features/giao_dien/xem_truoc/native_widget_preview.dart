import 'dart:convert';
import 'dart:typed_data';

import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_tokens.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/widget_theme_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class NativeWidgetPreview {
  const new();

  static const _channel = MethodChannel('better_phenikaa/widget_render');

  Future<Uint8List?> render({
    required WidgetSurfaceKind surface,
    required ThemeTokens tokens,
    required WidgetThemeConfiguration configuration,
    String fontFamily = '',
    String fontPath = '',
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final (width, height) = switch (surface) {
      WidgetSurfaceKind.small => (320, 64),
      WidgetSurfaceKind.large => (320, 150),
      WidgetSurfaceKind.widget2 => (320, 150),
    };
    try {
      return await _channel.invokeMethod<Uint8List>(
        'renderPreview',
        <String, Object>{
          'surface': surface.name,
          'widthDp': width,
          'heightDp': height,
          'theme': 'custom',
          'widgetStart': tokens.widgetStart.toARGB32(),
          'widgetEnd': tokens.widgetEnd.toARGB32(),
          'widgetText': tokens.widgetText.toARGB32(),
          'widgetSubtext': tokens.widgetSubtext.toARGB32(),
          'widgetIcon': tokens.widgetText.toARGB32(),
          'widgetConfig': jsonEncode(configuration.toJson()),
          'fontFamily': fontFamily,
          'fontPath': fontPath,
        },
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
