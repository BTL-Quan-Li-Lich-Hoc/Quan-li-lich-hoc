import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum WidgetSurfaceKind { small, large, widget2 }

@immutable
final class WidgetImageCrop {
  const new({this.left = 0, this.top = 0, this.right = 1, this.bottom = 1});

  factory WidgetImageCrop.fromJson(Map<String, Object?> json) =>
      WidgetImageCrop(
        left: ((json['left'] as num?)?.toDouble() ?? 0).clamp(0, 1),
        top: ((json['top'] as num?)?.toDouble() ?? 0).clamp(0, 1),
        right: ((json['right'] as num?)?.toDouble() ?? 1).clamp(0, 1),
        bottom: ((json['bottom'] as num?)?.toDouble() ?? 1).clamp(0, 1),
      );

  final double left;
  final double top;
  final double right;
  final double bottom;

  Map<String, Object?> toJson() => <String, Object?>{
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };
}

@immutable
final class WidgetBorderDefinition {
  const new({
    this.enabled = false,
    this.color = const Color(0xFFFFD66B),
    this.width = 1,
    this.tienMonStyle = false,
  });

  factory WidgetBorderDefinition.fromJson(Map<String, Object?> json) =>
      WidgetBorderDefinition(
        enabled: json['enabled'] as bool? ?? false,
        color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFD66B),
        width: ((json['widthDp'] as num?)?.toDouble() ?? 1).clamp(.5, 16),
        tienMonStyle: json['tienMonStyle'] as bool? ?? false,
      );

  final bool enabled;
  final Color color;
  final double width;
  final bool tienMonStyle;

  WidgetBorderDefinition copyWith({
    bool? enabled,
    Color? color,
    double? width,
    bool? tienMonStyle,
  }) => WidgetBorderDefinition(
    enabled: enabled ?? this.enabled,
    color: color ?? this.color,
    width: width ?? this.width,
    tienMonStyle: tienMonStyle ?? this.tienMonStyle,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'color': color.toARGB32(),
    'widthDp': width,
    'tienMonStyle': tienMonStyle,
  };
}

@immutable
final class WidgetThemeConfiguration {
  const new({
    this.largeImagePath = '',
    this.largeImageCrop = const WidgetImageCrop(),
    this.widget2ImagePath = '',
    this.widget2ImageCrop = const WidgetImageCrop(),
    this.smallBorder = const WidgetBorderDefinition(),
    this.largeBorder = const WidgetBorderDefinition(),
    this.widget2Border = const WidgetBorderDefinition(),
    this.textColors = const <WidgetSurfaceKind, Color>{},
    this.cornerRadius = 18,
    this.glassOpacity = .58,
    this.glowStrength = .32,
  });

  factory WidgetThemeConfiguration.fromJson(Map<String, Object?> json) {
    WidgetBorderDefinition border(String key) {
      final value = json[key];
      if (value is! Map<Object?, Object?>) {
        return const WidgetBorderDefinition();
      }
      return WidgetBorderDefinition.fromJson(Map<String, Object?>.from(value));
    }

    return WidgetThemeConfiguration(
      largeImagePath: json['largeImagePath'] as String? ?? '',
      largeImageCrop: json['largeImageCrop'] is Map
          ? WidgetImageCrop.fromJson(
              Map<String, Object?>.from(json['largeImageCrop'] as Map),
            )
          : const WidgetImageCrop(),
      widget2ImagePath: json['widget2ImagePath'] as String? ?? '',
      widget2ImageCrop: json['widget2ImageCrop'] is Map
          ? WidgetImageCrop.fromJson(
              Map<String, Object?>.from(json['widget2ImageCrop'] as Map),
            )
          : const WidgetImageCrop(),
      smallBorder: border('smallBorder'),
      largeBorder: border('largeBorder'),
      widget2Border: border('widget2Border'),
      textColors: <WidgetSurfaceKind, Color>{
        if (json['smallTextColor'] is num)
          WidgetSurfaceKind.small: Color((json['smallTextColor'] as num).toInt()),
        if (json['largeTextColor'] is num)
          WidgetSurfaceKind.large: Color((json['largeTextColor'] as num).toInt()),
        if (json['widget2TextColor'] is num)
          WidgetSurfaceKind.widget2: Color((json['widget2TextColor'] as num).toInt()),
      },
      cornerRadius: ((json['cornerRadiusDp'] as num?)?.toDouble() ?? 18).clamp(
        0,
        28,
      ),
      glassOpacity: ((json['glassOpacity'] as num?)?.toDouble() ?? .58).clamp(
        .18,
        .92,
      ),
      glowStrength: ((json['glowStrength'] as num?)?.toDouble() ?? .32).clamp(
        0,
        1,
      ),
    );
  }

  final String largeImagePath;
  final WidgetImageCrop largeImageCrop;
  final String widget2ImagePath;
  final WidgetImageCrop widget2ImageCrop;
  final WidgetBorderDefinition smallBorder;
  final WidgetBorderDefinition largeBorder;
  final WidgetBorderDefinition widget2Border;
  final Map<WidgetSurfaceKind, Color> textColors;
  final double cornerRadius;
  final double glassOpacity;
  final double glowStrength;

  WidgetBorderDefinition borderFor(WidgetSurfaceKind kind) => switch (kind) {
    WidgetSurfaceKind.small => smallBorder,
    WidgetSurfaceKind.large => largeBorder,
    WidgetSurfaceKind.widget2 => widget2Border,
  };

  WidgetThemeConfiguration withBorder(
    WidgetSurfaceKind kind,
    WidgetBorderDefinition border,
  ) => switch (kind) {
    WidgetSurfaceKind.small => copyWith(smallBorder: border),
    WidgetSurfaceKind.large => copyWith(largeBorder: border),
    WidgetSurfaceKind.widget2 => copyWith(widget2Border: border),
  };

  Color? textColorFor(WidgetSurfaceKind kind) => textColors[kind];

  WidgetThemeConfiguration withTextColor(WidgetSurfaceKind kind, Color? color) {
    final updated = Map<WidgetSurfaceKind, Color>.of(textColors);
    if (color == null) {
      updated.remove(kind);
    } else {
      updated[kind] = color;
    }
    return copyWith(textColors: updated);
  }

  WidgetThemeConfiguration copyWith({
    String? largeImagePath,
    WidgetImageCrop? largeImageCrop,
    String? widget2ImagePath,
    WidgetImageCrop? widget2ImageCrop,
    WidgetBorderDefinition? smallBorder,
    WidgetBorderDefinition? largeBorder,
    WidgetBorderDefinition? widget2Border,
    Map<WidgetSurfaceKind, Color>? textColors,
    double? cornerRadius,
    double? glassOpacity,
    double? glowStrength,
  }) => WidgetThemeConfiguration(
    largeImagePath: largeImagePath ?? this.largeImagePath,
    largeImageCrop: largeImageCrop ?? this.largeImageCrop,
    widget2ImagePath: widget2ImagePath ?? this.widget2ImagePath,
    widget2ImageCrop: widget2ImageCrop ?? this.widget2ImageCrop,
    smallBorder: smallBorder ?? this.smallBorder,
    largeBorder: largeBorder ?? this.largeBorder,
    widget2Border: widget2Border ?? this.widget2Border,
    textColors: textColors ?? this.textColors,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glowStrength: glowStrength ?? this.glowStrength,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 1,
    'largeImagePath': largeImagePath,
    'largeImageCrop': largeImageCrop.toJson(),
    'widget2ImagePath': widget2ImagePath,
    'widget2ImageCrop': widget2ImageCrop.toJson(),
    'smallBorder': smallBorder.toJson(),
    'largeBorder': largeBorder.toJson(),
    'widget2Border': widget2Border.toJson(),
    'smallTextColor': textColors[WidgetSurfaceKind.small]?.toARGB32(),
    'largeTextColor': textColors[WidgetSurfaceKind.large]?.toARGB32(),
    'widget2TextColor': textColors[WidgetSurfaceKind.widget2]?.toARGB32(),
    'cornerRadiusDp': cornerRadius,
    'glassOpacity': glassOpacity,
    'glowStrength': glowStrength,
  };
}
