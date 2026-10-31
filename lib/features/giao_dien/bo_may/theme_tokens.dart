import 'package:flutter/material.dart';

/// Hợp đồng màu đầy đủ, độc lập nền tảng cho app và widget.
///
/// Presets and generated themes both pass through this model. Keeping the roles
/// explicit prevents feature widgets from inventing one-off colors.
@immutable
final class ThemeTokens {
  const new({
    required this.background,
    required this.backgroundEnd,
    required this.surface,
    required this.card,
    required this.cardAlternate,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.icon,
    required this.border,
    required this.divider,
    required this.selected,
    required this.pressed,
    required this.disabled,
    required this.success,
    required this.warning,
    required this.error,
    required this.widgetStart,
    required this.widgetEnd,
    required this.widgetText,
    required this.widgetSubtext,
    required this.shadow,
    required this.dark,
    required this.radius,
  });

  factory lerp(ThemeTokens from, ThemeTokens to, double progress) {
    final t = progress.clamp(0.0, 1.0);
    Color blend(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return ThemeTokens(
      background: blend(from.background, to.background),
      backgroundEnd: blend(from.backgroundEnd, to.backgroundEnd),
      surface: blend(from.surface, to.surface),
      card: blend(from.card, to.card),
      cardAlternate: blend(from.cardAlternate, to.cardAlternate),
      primary: blend(from.primary, to.primary),
      secondary: blend(from.secondary, to.secondary),
      accent: blend(from.accent, to.accent),
      textPrimary: blend(from.textPrimary, to.textPrimary),
      textSecondary: blend(from.textSecondary, to.textSecondary),
      icon: blend(from.icon, to.icon),
      border: blend(from.border, to.border),
      divider: blend(from.divider, to.divider),
      selected: blend(from.selected, to.selected),
      pressed: blend(from.pressed, to.pressed),
      disabled: blend(from.disabled, to.disabled),
      success: blend(from.success, to.success),
      warning: blend(from.warning, to.warning),
      error: blend(from.error, to.error),
      widgetStart: blend(from.widgetStart, to.widgetStart),
      widgetEnd: blend(from.widgetEnd, to.widgetEnd),
      widgetText: blend(from.widgetText, to.widgetText),
      widgetSubtext: blend(from.widgetSubtext, to.widgetSubtext),
      shadow: blend(from.shadow, to.shadow),
      dark: t < 1 ? from.dark : to.dark,
      radius: from.radius + ((to.radius - from.radius) * t),
    );
  }

  factory fromJson(Map<String, Object?> json) {
    Color color(String key, int fallback) {
      final value = json[key];
      return Color(value is num ? value.toInt() : fallback);
    }

    return ThemeTokens(
      background: color('background', 0xFFF9FBFF),
      backgroundEnd: color('backgroundEnd', 0xFFF2F6FF),
      surface: color('surface', 0xFFFFFFFF),
      card: color('card', 0xFFFFFFFF),
      cardAlternate: color('cardAlternate', 0xFFF3F6FC),
      primary: color('primary', 0xFF1747B5),
      secondary: color('secondary', 0xFF315AB5),
      accent: color('accent', 0xFF4A89FF),
      textPrimary: color('textPrimary', 0xFF102B73),
      textSecondary: color('textSecondary', 0xFF7180A0),
      icon: color('icon', 0xFF102B73),
      border: color('border', 0xFFE8EDF7),
      divider: color('divider', 0xFFE8EDF7),
      selected: color('selected', 0xFFE4ECFF),
      pressed: color('pressed', 0xFF123992),
      disabled: color('disabled', 0xFFB7C0D4),
      success: color('success', 0xFF168A45),
      warning: color('warning', 0xFF9A6500),
      error: color('error', 0xFFB3261E),
      widgetStart: color('widgetStart', 0xFF173A8E),
      widgetEnd: color('widgetEnd', 0xFF315AB5),
      widgetText: color('widgetText', 0xFFFFFFFF),
      widgetSubtext: color('widgetSubtext', 0xFFDDE8FF),
      shadow: color('shadow', 0x18193B80),
      dark: json['dark'] == true,
      radius: (json['radius'] as num?)?.toDouble() ?? 14,
    );
  }

  final Color background;
  final Color backgroundEnd;
  final Color surface;
  final Color card;
  final Color cardAlternate;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color icon;
  final Color border;
  final Color divider;
  final Color selected;
  final Color pressed;
  final Color disabled;
  final Color success;
  final Color warning;
  final Color error;
  final Color widgetStart;
  final Color widgetEnd;
  final Color widgetText;
  final Color widgetSubtext;
  final Color shadow;
  final bool dark;
  final double radius;

  Map<String, Object> toJson() => <String, Object>{
    'background': background.toARGB32(),
    'backgroundEnd': backgroundEnd.toARGB32(),
    'surface': surface.toARGB32(),
    'card': card.toARGB32(),
    'cardAlternate': cardAlternate.toARGB32(),
    'primary': primary.toARGB32(),
    'secondary': secondary.toARGB32(),
    'accent': accent.toARGB32(),
    'textPrimary': textPrimary.toARGB32(),
    'textSecondary': textSecondary.toARGB32(),
    'icon': icon.toARGB32(),
    'border': border.toARGB32(),
    'divider': divider.toARGB32(),
    'selected': selected.toARGB32(),
    'pressed': pressed.toARGB32(),
    'disabled': disabled.toARGB32(),
    'success': success.toARGB32(),
    'warning': warning.toARGB32(),
    'error': error.toARGB32(),
    'widgetStart': widgetStart.toARGB32(),
    'widgetEnd': widgetEnd.toARGB32(),
    'widgetText': widgetText.toARGB32(),
    'widgetSubtext': widgetSubtext.toARGB32(),
    'shadow': shadow.toARGB32(),
    'dark': dark,
    'radius': radius,
  };
}

double contrastRatio(Color foreground, Color background) {
  final high = foreground.computeLuminance();
  final low = background.computeLuminance();
  final lighter = high > low ? high : low;
  final darker = high > low ? low : high;
  return (lighter + 0.05) / (darker + 0.05);
}

Color mixColors(Color first, Color second, double amount) =>
    Color.lerp(first, second, amount.clamp(0.0, 1.0)) ?? second;
