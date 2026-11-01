import 'dart:async';
import 'dart:convert';

import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_tokens.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme_repository.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_manager.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/background/tien_mon_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeId {
  classic,
  lol,
  valorant,
  minecraft,
  facebook,
  shopee,
  tiktok,
  ben10,
  youtube,
  steam,
  tienMonPremium,
  custom,
}

enum AppThemeGeometry { rounded, square, valorant, lol, pixel }

extension AppThemeIdUi on AppThemeId {
  String get storageKey =>
      this == AppThemeId.tienMonPremium ? 'tien_mon_premium' : name;

  String get label => switch (this) {
    AppThemeId.classic => 'Better mặc định',
    AppThemeId.lol => 'League of Legends',
    AppThemeId.valorant => 'Valorant',
    AppThemeId.minecraft => 'Minecraft',
    AppThemeId.facebook => 'Facebook',
    AppThemeId.shopee => 'Shopee',
    AppThemeId.tiktok => 'TikTok',
    AppThemeId.ben10 => 'Ben 10',
    AppThemeId.youtube => 'YouTube',
    AppThemeId.steam => 'Steam',
    AppThemeId.tienMonPremium => 'Tiên Môn Premium',
    AppThemeId.custom => 'Tùy chỉnh',
  };

  String get caption => switch (this) {
    AppThemeId.classic => 'Sạch, xanh, quen thuộc',
    AppThemeId.lol => 'Hextech • vàng • lam ngọc',
    AppThemeId.valorant => 'Tactical • đỏ • góc cắt',
    AppThemeId.minecraft => 'Pixel • đất • nút khối',
    AppThemeId.facebook => 'Feed sáng • xanh Facebook',
    AppThemeId.shopee => 'Cam thương mại • card sáng',
    AppThemeId.tiktok => 'Đen • hồng • cyan',
    AppThemeId.ben10 => 'Omnitrix • đen • xanh neon',
    AppThemeId.youtube => 'Dark feed • đỏ video',
    AppThemeId.steam => 'Store dark • xanh Steam',
    AppThemeId.tienMonPremium => 'Cổ trang • live wallpaper • kim ngọc',
    AppThemeId.custom => 'Màu và font do bạn tạo',
  };

  IconData get icon => switch (this) {
    AppThemeId.classic => Icons.check_rounded,
    AppThemeId.lol => Icons.auto_awesome_rounded,
    AppThemeId.valorant => Icons.change_history_rounded,
    AppThemeId.minecraft => Icons.view_in_ar_rounded,
    AppThemeId.facebook => Icons.facebook,
    AppThemeId.shopee => Icons.shopping_bag_rounded,
    AppThemeId.tiktok => Icons.music_note_rounded,
    AppThemeId.ben10 => Icons.watch_rounded,
    AppThemeId.youtube => Icons.play_circle_fill_rounded,
    AppThemeId.steam => Icons.sports_esports_rounded,
    AppThemeId.tienMonPremium => Icons.auto_awesome_rounded,
    AppThemeId.custom => Icons.tune_rounded,
  };
}

@immutable
class AppThemePalette {
  const new({
    required this.id,
    required this.pageStart,
    required this.pageEnd,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.widgetStart,
    required this.widgetEnd,
    required this.widgetText,
    required this.widgetSubtext,
    required this.radius,
    required this.geometry,
    required this.dark,
    this.fontFamily,
  });

  factory fromTokens(
    ThemeTokens tokens, {
    required AppThemeId id,
    AppThemeGeometry geometry = AppThemeGeometry.rounded,
    String? fontFamily,
  }) => AppThemePalette(
    id: id,
    pageStart: tokens.background,
    pageEnd: tokens.backgroundEnd,
    surface: tokens.surface,
    card: tokens.card,
    cardAlt: tokens.cardAlternate,
    primary: tokens.primary,
    accent: tokens.accent,
    textPrimary: tokens.textPrimary,
    textSecondary: tokens.textSecondary,
    border: tokens.border,
    shadow: tokens.shadow,
    widgetStart: tokens.widgetStart,
    widgetEnd: tokens.widgetEnd,
    widgetText: tokens.widgetText,
    widgetSubtext: tokens.widgetSubtext,
    radius: tokens.radius,
    geometry: geometry,
    dark: tokens.dark,
    fontFamily: fontFamily,
  );

  final AppThemeId id;
  final Color pageStart;
  final Color pageEnd;
  final Color surface;
  final Color card;
  final Color cardAlt;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final Color widgetStart;
  final Color widgetEnd;
  final Color widgetText;
  final Color widgetSubtext;
  final double radius;
  final AppThemeGeometry geometry;
  final bool dark;
  final String? fontFamily;

  AppThemePalette withTextColors(Color primaryText, Color secondaryText) =>
      AppThemePalette(
        id: id,
        pageStart: pageStart,
        pageEnd: pageEnd,
        surface: surface,
        card: card,
        cardAlt: cardAlt,
        primary: primary,
        accent: accent,
        textPrimary: primaryText,
        textSecondary: secondaryText,
        border: border,
        shadow: shadow,
        widgetStart: widgetStart,
        widgetEnd: widgetEnd,
        widgetText: widgetText,
        widgetSubtext: widgetSubtext,
        radius: radius,
        geometry: geometry,
        dark: dark,
        fontFamily: fontFamily,
      );

  AppThemePalette withFontFamily(String? family) => AppThemePalette(
    id: id,
    pageStart: pageStart,
    pageEnd: pageEnd,
    surface: surface,
    card: card,
    cardAlt: cardAlt,
    primary: primary,
    accent: accent,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    border: border,
    shadow: shadow,
    widgetStart: widgetStart,
    widgetEnd: widgetEnd,
    widgetText: widgetText,
    widgetSubtext: widgetSubtext,
    radius: radius,
    geometry: geometry,
    dark: dark,
    fontFamily: family,
  );

  ThemeTokens toTokens() => ThemeTokens(
    background: pageStart,
    backgroundEnd: pageEnd,
    surface: surface,
    card: card,
    cardAlternate: cardAlt,
    primary: primary,
    secondary: mixColors(primary, accent, 0.42),
    accent: accent,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    icon: textPrimary,
    border: border,
    divider: border,
    selected: mixColors(card, primary, dark ? 0.28 : 0.12),
    pressed: mixColors(primary, textPrimary, dark ? 0.18 : 0.10),
    disabled: mixColors(textSecondary, surface, 0.48),
    success: const Color(0xFF168A45),
    warning: const Color(0xFFE08A00),
    error: const Color(0xFFD83B45),
    widgetStart: widgetStart,
    widgetEnd: widgetEnd,
    widgetText: widgetText,
    widgetSubtext: widgetSubtext,
    shadow: shadow,
    dark: dark,
    radius: radius,
  );
}

const Map<AppThemeId, AppThemePalette> appThemePalettes =
    <AppThemeId, AppThemePalette>{
      AppThemeId.classic: AppThemePalette(
        id: AppThemeId.classic,
        pageStart: Color(0xFFF9FBFF),
        pageEnd: Color(0xFFF2F6FF),
        surface: Color(0xFFFFFFFF),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFF3F6FC),
        primary: Color(0xFF1747B5),
        accent: Color(0xFF4A89FF),
        textPrimary: Color(0xFF102B73),
        textSecondary: Color(0xFF7180A0),
        border: Color(0xFFE8EDF7),
        shadow: Color(0x18193B80),
        widgetStart: Color(0xFF173A8E),
        widgetEnd: Color(0xFF315AB5),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFDDE8FF),
        radius: 14,
        geometry: AppThemeGeometry.rounded,
        dark: false,
      ),
      AppThemeId.lol: AppThemePalette(
        id: AppThemeId.lol,
        pageStart: Color(0xFF030B10),
        pageEnd: Color(0xFF071821),
        surface: Color(0xFF07161D),
        card: Color(0xFF0B1A21),
        cardAlt: Color(0xFF0F252D),
        primary: Color(0xFF0AC8B9),
        accent: Color(0xFFC89B3C),
        textPrimary: Color(0xFFF0E6D2),
        textSecondary: Color(0xFF9D947F),
        border: Color(0xFF785A28),
        shadow: Color(0x66000000),
        widgetStart: Color(0xFF06131A),
        widgetEnd: Color(0xFF0B343A),
        widgetText: Color(0xFFF0E6D2),
        widgetSubtext: Color(0xFFC8AA6E),
        radius: 2,
        geometry: AppThemeGeometry.lol,
        dark: true,
      ),
      AppThemeId.valorant: AppThemePalette(
        id: AppThemeId.valorant,
        pageStart: Color(0xFF0F1923),
        pageEnd: Color(0xFF111D27),
        surface: Color(0xFF111D27),
        card: Color(0xFF14222D),
        cardAlt: Color(0xFF1D2A34),
        primary: Color(0xFFFF4655),
        accent: Color(0xFFECE8E1),
        textPrimary: Color(0xFFECE8E1),
        textSecondary: Color(0xFF9AA7AD),
        border: Color(0xFF3A4A55),
        shadow: Color(0x66000000),
        widgetStart: Color(0xFF0F1923),
        widgetEnd: Color(0xFF24313B),
        widgetText: Color(0xFFECE8E1),
        widgetSubtext: Color(0xFFFF7B86),
        radius: 2,
        geometry: AppThemeGeometry.valorant,
        dark: true,
      ),
      AppThemeId.minecraft: AppThemePalette(
        id: AppThemeId.minecraft,
        pageStart: Color(0xFF5C3922),
        pageEnd: Color(0xFF352116),
        surface: Color(0xFF261D16),
        card: Color(0xFF30241B),
        cardAlt: Color(0xFF5D5D5D),
        primary: Color(0xFF8BC34A),
        accent: Color(0xFFFFFFFF),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFD8D1C9),
        border: Color(0xFF0B0907),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF3A2B20),
        widgetEnd: Color(0xFF6B4A2F),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFD8D1C9),
        radius: 0,
        geometry: AppThemeGeometry.pixel,
        dark: true,
        fontFamily: 'MinecraftCustom',
      ),
      AppThemeId.facebook: AppThemePalette(
        id: AppThemeId.facebook,
        pageStart: Color(0xFFF0F2F5),
        pageEnd: Color(0xFFF0F2F5),
        surface: Color(0xFFF0F2F5),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFE7F3FF),
        primary: Color(0xFF0866FF),
        accent: Color(0xFF0866FF),
        textPrimary: Color(0xFF050505),
        textSecondary: Color(0xFF65676B),
        border: Color(0xFFE4E6EB),
        shadow: Color(0x18000000),
        widgetStart: Color(0xFFFFFFFF),
        widgetEnd: Color(0xFFE7F3FF),
        widgetText: Color(0xFF050505),
        widgetSubtext: Color(0xFF65676B),
        radius: 16,
        geometry: AppThemeGeometry.rounded,
        dark: false,
      ),
      AppThemeId.shopee: AppThemePalette(
        id: AppThemeId.shopee,
        pageStart: Color(0xFFFFF5F1),
        pageEnd: Color(0xFFF7F7F7),
        surface: Color(0xFFF6F6F6),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFFFE9E1),
        primary: Color(0xFFEE4D2D),
        accent: Color(0xFFFF8B5E),
        textPrimary: Color(0xFF222222),
        textSecondary: Color(0xFF777777),
        border: Color(0xFFEAEAEA),
        shadow: Color(0x16000000),
        widgetStart: Color(0xFFEE4D2D),
        widgetEnd: Color(0xFFFF6A3D),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFFFE9E1),
        radius: 15,
        geometry: AppThemeGeometry.rounded,
        dark: false,
      ),
      AppThemeId.tiktok: AppThemePalette(
        id: AppThemeId.tiktok,
        pageStart: Color(0xFF000000),
        pageEnd: Color(0xFF111111),
        surface: Color(0xFF0A0A0A),
        card: Color(0xFF202020),
        cardAlt: Color(0xFF2A2A2A),
        primary: Color(0xFFFE2C55),
        accent: Color(0xFF25F4EE),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFB8B8B8),
        border: Color(0xFF343434),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF111111),
        widgetEnd: Color(0xFF2A1520),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFF25F4EE),
        radius: 14,
        geometry: AppThemeGeometry.rounded,
        dark: true,
      ),
      AppThemeId.ben10: AppThemePalette(
        id: AppThemeId.ben10,
        pageStart: Color(0xFF050805),
        pageEnd: Color(0xFF142016),
        surface: Color(0xFF101510),
        card: Color(0xFF182018),
        cardAlt: Color(0xFF243126),
        primary: Color(0xFF39D353),
        accent: Color(0xFF7CFF00),
        textPrimary: Color(0xFFF5FFF5),
        textSecondary: Color(0xFFA8B8A9),
        border: Color(0xFF315637),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF101510),
        widgetEnd: Color(0xFF1D5F22),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFF7CFF00),
        radius: 18,
        geometry: AppThemeGeometry.rounded,
        dark: true,
      ),
      AppThemeId.youtube: AppThemePalette(
        id: AppThemeId.youtube,
        pageStart: Color(0xFF0F0F0F),
        pageEnd: Color(0xFF151515),
        surface: Color(0xFF0F0F0F),
        card: Color(0xFF212121),
        cardAlt: Color(0xFF272727),
        primary: Color(0xFFFF0033),
        accent: Color(0xFFFFFFFF),
        textPrimary: Color(0xFFF1F1F1),
        textSecondary: Color(0xFFAAAAAA),
        border: Color(0xFF303030),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF181818),
        widgetEnd: Color(0xFF2B0E14),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFFF8A9F),
        radius: 14,
        geometry: AppThemeGeometry.rounded,
        dark: true,
      ),
      AppThemeId.steam: AppThemePalette(
        id: AppThemeId.steam,
        pageStart: Color(0xFF0E141B),
        pageEnd: Color(0xFF162536),
        surface: Color(0xFF171D25),
        card: Color(0xFF1B2838),
        cardAlt: Color(0xFF22384A),
        primary: Color(0xFF66C0F4),
        accent: Color(0xFF1A9FFF),
        textPrimary: Color(0xFFD6E9F8),
        textSecondary: Color(0xFF8F98A0),
        border: Color(0xFF2A475E),
        shadow: Color(0x66000000),
        widgetStart: Color(0xFF171D25),
        widgetEnd: Color(0xFF1B3D55),
        widgetText: Color(0xFFD6E9F8),
        widgetSubtext: Color(0xFF66C0F4),
        radius: 4,
        geometry: AppThemeGeometry.square,
        dark: true,
      ),
      AppThemeId.tienMonPremium: AppThemePalette(
        id: AppThemeId.tienMonPremium,
        pageStart: Color(0xFF071713),
        pageEnd: Color(0xFF102820),
        surface: Color(0xCC071713),
        card: Color(0x14000000),
        cardAlt: Color(0x18000000),
        primary: Color(0xFFFFD66B),
        accent: Color(0xFF74D8B1),
        textPrimary: Color(0xFFFFD66B),
        textSecondary: Color(0xFFFFE7A6),
        border: Color(0xCCFFD66B),
        shadow: Color(0x99000000),
        widgetStart: Color(0xFF12372E),
        widgetEnd: Color(0xFF477B68),
        widgetText: Color(0xFFFFD66B),
        widgetSubtext: Color(0xFFFFE7A6),
        radius: 18,
        geometry: AppThemeGeometry.rounded,
        dark: true,
        fontFamily: 'FzCoTrang',
      ),
    };

AppThemePalette get appThemePalette => AppThemeController.instance.palette;

class AppThemeController extends ChangeNotifier {
  new _();

  static final AppThemeController instance = AppThemeController._();
  static const _preferenceKey = 'better_phenikaa_theme_v3';
  static const _legacyPreferenceKey = 'better_phenikaa_theme_v2';
  static const _appliedCustomThemeKey =
      'better_phenikaa_applied_custom_theme_v1';
  static const _widgetPreferenceKey = 'appTheme';
  static const _tienMonTextPrimaryKey = 'tien_mon_text_primary_v1';
  static const _tienMonTextSecondaryKey = 'tien_mon_text_secondary_v1';
  static const _tienMonFontKey = 'tien_mon_font_v1';
  static const AppFontChoice tienMonDefaultFont = AppFontChoice(
    id: 'tien_mon_default',
    label: 'Tiên Môn mặc định',
    kind: AppFontKind.builtIn,
    family: 'FzCoTrang',
  );
  static const MethodChannel _widgetThemeChannel = MethodChannel(
    'better_phenikaa/widget_theme',
  );

  AppThemeId _theme = AppThemeId.classic;
  CustomThemeDefinition? _activeCustomTheme;
  String? _activeCustomFontFamily;
  List<CustomThemeDefinition> _customThemes = <CustomThemeDefinition>[];
  AppThemePalette? _transitionPalette;
  Timer? _transitionTimer;
  Completer<void>? _transitionCompletion;
  int _transitionSerial = 0;
  bool _loaded = false;
  Color _tienMonTextPrimary = const Color(0xFFFFD66B);
  Color _tienMonTextSecondary = const Color(0xFFFFE7A6);
  AppFontChoice _tienMonFont = tienMonDefaultFont;
  String? _tienMonFontFamily = tienMonDefaultFont.family;

  AppThemeId get theme => _theme;
  Color get tienMonTextPrimary => _tienMonTextPrimary;
  Color get tienMonTextSecondary => _tienMonTextSecondary;
  AppFontChoice get tienMonFont => _tienMonFont;
  String? get tienMonFontFamily => _tienMonFontFamily;
  AppThemePalette get palette =>
      _transitionPalette ?? _resolvedPalette(_theme, _activeCustomTheme);
  List<CustomThemeDefinition> get customThemes =>
      List<CustomThemeDefinition>.unmodifiable(_customThemes);
  CustomThemeDefinition? get activeCustomTheme => _activeCustomTheme;
  bool get isTransitioning => _transitionPalette != null;

  void resetAfterLogout() {
    _transitionTimer?.cancel();
    _transitionTimer = null;
    final pending = _transitionCompletion;
    if (pending != null && !pending.isCompleted) pending.complete();
    _transitionCompletion = null;
    _transitionSerial++;
    _transitionPalette = null;
    _theme = AppThemeId.classic;
    _activeCustomTheme = null;
    _activeCustomFontFamily = null;
    _customThemes = <CustomThemeDefinition>[];
    notifyListeners();
  }

  AppThemePalette _resolvedPalette(
    AppThemeId id,
    CustomThemeDefinition? custom,
  ) {
    if (id == AppThemeId.custom && custom != null) {
      return AppThemePalette.fromTokens(
        custom.tokens,
        id: AppThemeId.custom,
        fontFamily: _activeCustomFontFamily,
      );
    }
    final base = appThemePalettes[id] ?? appThemePalettes[AppThemeId.classic]!;
    if (id == AppThemeId.tienMonPremium) {
      return base
          .withTextColors(_tienMonTextPrimary, _tienMonTextSecondary)
          .withFontFamily(_tienMonFontFamily);
    }
    return base;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _tienMonTextPrimary = Color(
      prefs.getInt(_tienMonTextPrimaryKey) ?? 0xFFFFD66B,
    );
    _tienMonTextSecondary = Color(
      prefs.getInt(_tienMonTextSecondaryKey) ?? 0xFFFFE7A6,
    );
    final savedTienMonFont = prefs.getString(_tienMonFontKey);
    if (savedTienMonFont != null) {
      try {
        final decoded = jsonDecode(savedTienMonFont);
        if (decoded is Map<String, dynamic>) {
          _tienMonFont = AppFontChoice.fromJson(
            Map<String, Object?>.from(decoded),
          );
        }
      } on Object {
        _tienMonFont = tienMonDefaultFont;
      }
    }
    _tienMonFontFamily = await ThemeFontManager.instance.resolveFamily(
      _tienMonFont,
    );
    if (_tienMonFont.kind == AppFontKind.imported &&
        _tienMonFontFamily == null) {
      _tienMonFont = tienMonDefaultFont;
      _tienMonFontFamily = tienMonDefaultFont.family;
      await prefs.remove(_tienMonFontKey);
    }
    _customThemes = await const CustomThemeRepository().readAll();
    final saved =
        prefs.getString(_preferenceKey) ??
        prefs.getString(_legacyPreferenceKey);
    if (saved != null && saved.startsWith('custom:')) {
      final customId = saved.substring('custom:'.length);
      CustomThemeDefinition? applied;
      final appliedRaw = prefs.getString(_appliedCustomThemeKey);
      if (appliedRaw != null) {
        try {
          final decoded = jsonDecode(appliedRaw);
          if (decoded is Map<String, dynamic>) {
            final candidate = CustomThemeDefinition.fromJson(
              Map<String, Object?>.from(decoded),
            );
            if (candidate.id == customId) applied = candidate;
          }
        } on Object {
          applied = null;
        }
      }
      final match = _customThemes.where((item) => item.id == customId);
      final restored = applied ?? (match.isNotEmpty ? match.first : null);
      if (restored != null) {
        _activeCustomTheme = restored;
        _activeCustomFontFamily = await ThemeFontManager.instance.resolveFamily(
          restored.font,
        );
        _theme = AppThemeId.custom;
      }
    } else if (saved != null) {
      for (final candidate in AppThemeId.values) {
        if (candidate != AppThemeId.custom && candidate.storageKey == saved) {
          _theme = candidate;
          break;
        }
      }
    }
    final widgetKey = _widgetThemeKey;
    if (!prefs.containsKey(_widgetPreferenceKey)) {
      await prefs.setString(_widgetPreferenceKey, widgetKey);
    }
    notifyListeners();
    final widgetTheme = prefs.getString(_widgetPreferenceKey);
    final nativeApplied = await _applyWidgetTheme(widgetKey, palette);
    if (widgetTheme != widgetKey && !nativeApplied) {
      await prefs.setString(_widgetPreferenceKey, widgetKey);
      await _syncWidgetTheme();
    }
  }

  Future<void> setTienMonTextColors(Color primary, Color secondary) async {
    _tienMonTextPrimary = primary;
    _tienMonTextSecondary = secondary;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tienMonTextPrimaryKey, primary.toARGB32());
    await prefs.setInt(_tienMonTextSecondaryKey, secondary.toARGB32());
    notifyListeners();
  }

  Future<void> setTienMonFont(AppFontChoice choice) async {
    final resolved = await ThemeFontManager.instance.resolveFamily(choice);
    if (choice.kind == AppFontKind.imported && resolved == null) {
      throw const FormatException('Không đọc được font đã nhập.');
    }
    _tienMonFont = choice;
    _tienMonFontFamily = resolved;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tienMonFontKey, jsonEncode(choice.toJson()));
    notifyListeners();

    if (_theme == AppThemeId.tienMonPremium) {
      final target = _resolvedPalette(_theme, _activeCustomTheme);
      final widgetKey = _widgetThemeKey;
      final nativeApplied = await _applyWidgetTheme(widgetKey, target);
      if (!nativeApplied) {
        await prefs.setString(_widgetPreferenceKey, widgetKey);
        await _syncWidgetTheme();
      }
    }
  }

  Future<void> select(AppThemeId value) async {
    if (value == AppThemeId.custom ||
        (_theme == value && _activeCustomTheme == null)) {
      return;
    }
    await _transitionTo(themeId: value);
  }

  Future<void> applyCustomTheme(CustomThemeDefinition theme) async {
    final fontFamily = await ThemeFontManager.instance.resolveFamily(
      theme.font,
    );
    await _transitionTo(
      themeId: AppThemeId.custom,
      customTheme: theme,
      resolvedFontFamily: fontFamily,
    );
  }

  Future<void> saveCustomTheme(CustomThemeDefinition theme) async {
    final index = _customThemes.indexWhere((item) => item.id == theme.id);
    final next = List<CustomThemeDefinition>.of(_customThemes);
    if (index == -1) {
      next.add(theme);
    } else {
      next[index] = theme;
    }
    next.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    await const CustomThemeRepository().replaceAll(next);
    _customThemes = next;
    notifyListeners();
  }

  Future<void> deleteCustomTheme(String id) async {
    final next = _customThemes.where((item) => item.id != id).toList();
    if (next.length == _customThemes.length) {
      return;
    }
    await const CustomThemeRepository().replaceAll(next);
    _customThemes = next;
    if (_activeCustomTheme?.id == id) {
      await _transitionTo(themeId: AppThemeId.classic);
    } else {
      notifyListeners();
    }
  }

  Future<void> _transitionTo({
    required AppThemeId themeId,
    CustomThemeDefinition? customTheme,
    String? resolvedFontFamily,
  }) {
    final from = palette;
    final oldCustomFont = _activeCustomFontFamily;
    _activeCustomFontFamily = resolvedFontFamily;
    final target = _resolvedPalette(themeId, customTheme);
    _activeCustomFontFamily = oldCustomFont;

    _transitionTimer?.cancel();
    final interrupted = _transitionCompletion;
    if (interrupted != null && !interrupted.isCompleted) {
      interrupted.complete();
    }

    final completion = Completer<void>();
    _transitionCompletion = completion;
    final premiumHandoff =
        from.id == AppThemeId.tienMonPremium ||
        themeId == AppThemeId.tienMonPremium;

    if (premiumHandoff) {
      ++_transitionSerial;
      _transitionTimer = null;
      _theme = themeId;
      _activeCustomTheme = customTheme;
      _activeCustomFontFamily = resolvedFontFamily;
      _transitionPalette = null;
      notifyListeners();
      unawaited(() async {
        try {
          await _commitSelection(target);
          if (!completion.isCompleted) completion.complete();
        } on Object catch (error, stackTrace) {
          if (!completion.isCompleted) {
            completion.completeError(error, stackTrace);
          }
        } finally {
          if (_transitionCompletion == completion) {
            _transitionCompletion = null;
          }
        }
      }());
      return completion.future;
    }

    final serial = ++_transitionSerial;
    const frames = 15;
    var frame = 0;
    _transitionTimer = Timer.periodic(const Duration(milliseconds: 33), (
      timer,
    ) {
      if (serial != _transitionSerial) {
        timer.cancel();
        if (!completion.isCompleted) completion.complete();
        return;
      }
      frame += 1;
      final progress = frame / frames;
      if (frame < frames) {
        final tokens = ThemeTokens.lerp(
          from.toTokens(),
          target.toTokens(),
          progress,
        );
        _transitionPalette = AppThemePalette.fromTokens(
          tokens,
          id: from.id,
          geometry: from.geometry,
          fontFamily: from.fontFamily,
        );
        notifyListeners();
        return;
      }
      timer.cancel();
      _transitionTimer = null;
      _theme = themeId;
      _activeCustomTheme = customTheme;
      _activeCustomFontFamily = resolvedFontFamily;
      _transitionPalette = null;
      notifyListeners();
      unawaited(() async {
        try {
          await _commitSelection(target);
          if (!completion.isCompleted) completion.complete();
        } on Object catch (error, stackTrace) {
          if (!completion.isCompleted) {
            completion.completeError(error, stackTrace);
          }
        } finally {
          if (_transitionCompletion == completion) {
            _transitionCompletion = null;
          }
        }
      }());
    });
    return completion.future;
  }

  Future<void> _commitSelection(AppThemePalette target) async {
    final preferences = await SharedPreferences.getInstance();
    final selectionKey =
        _theme == AppThemeId.custom && _activeCustomTheme != null
        ? 'custom:${_activeCustomTheme!.id}'
        : _theme.storageKey;
    if (_theme == AppThemeId.custom && _activeCustomTheme != null) {
      final savedCustom = await preferences.setString(
        _appliedCustomThemeKey,
        jsonEncode(_activeCustomTheme!.toJson()),
      );
      if (!savedCustom) {
        throw StateError('Không thể lưu custom theme đang áp dụng.');
      }
    } else {
      await preferences.remove(_appliedCustomThemeKey);
    }
    final savedSelection = await preferences.setString(
      _preferenceKey,
      selectionKey,
    );
    if (!savedSelection) {
      throw StateError('Không thể lưu lựa chọn theme.');
    }
    final widgetKey = _widgetThemeKey;
    final nativeApplied = await _applyWidgetTheme(widgetKey, target);
    if (!nativeApplied) {
      await preferences.setString(_widgetPreferenceKey, widgetKey);
      await _syncWidgetTheme();
    }
  }

  String get _widgetThemeKey =>
      _theme == AppThemeId.custom ? 'custom' : _theme.storageKey;

  Future<bool> _applyWidgetTheme(
    String themeKey,
    AppThemePalette target,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _widgetThemeChannel.invokeMethod<int>(
        'applyTheme',
        <String, Object>{
          'theme': themeKey,
          'widgetStart': target.widgetStart.toARGB32(),
          'widgetEnd': target.widgetEnd.toARGB32(),
          'widgetText': target.widgetText.toARGB32(),
          'widgetSubtext': target.widgetSubtext.toARGB32(),
          'widgetIcon': target.widgetText.toARGB32(),
          'fontFamily': target.fontFamily ?? '',
          'fontPath': _theme == AppThemeId.custom
              ? _activeCustomTheme?.font.path ?? ''
              : _theme == AppThemeId.tienMonPremium
              ? _tienMonFont.path ?? ''
              : '',
        },
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _syncWidgetTheme() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      qualifiedAndroidName:
          'vn.edu.phenikaa.better_phenikaa_schedule.ScheduleWidgetProvider',
    );
  }
}

const List<Shadow> tienMonTextShadows = <Shadow>[
  Shadow(color: Color(0xB3000000), blurRadius: 2, offset: Offset(0, 1)),
];

TextTheme _withTienMonTextShadows(TextTheme theme) {
  TextStyle? shadow(TextStyle? style) =>
      style?.copyWith(shadows: tienMonTextShadows);
  return theme.copyWith(
    displayLarge: shadow(theme.displayLarge),
    displayMedium: shadow(theme.displayMedium),
    displaySmall: shadow(theme.displaySmall),
    headlineLarge: shadow(theme.headlineLarge),
    headlineMedium: shadow(theme.headlineMedium),
    headlineSmall: shadow(theme.headlineSmall),
    titleLarge: shadow(theme.titleLarge),
    titleMedium: shadow(theme.titleMedium),
    titleSmall: shadow(theme.titleSmall),
    bodyLarge: shadow(theme.bodyLarge),
    bodyMedium: shadow(theme.bodyMedium),
    bodySmall: shadow(theme.bodySmall),
    labelLarge: shadow(theme.labelLarge),
    labelMedium: shadow(theme.labelMedium),
    labelSmall: shadow(theme.labelSmall),
  );
}

ThemeData buildBetterTheme(AppThemePalette palette) {
  final brightness = palette.dark ? Brightness.dark : Brightness.light;
  final fontScale = themeFontSizeFactor(palette.fontFamily);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: palette.fontFamily ?? 'Roboto',
  );
  final shape = themeButtonShape(palette);
  final appliedTextTheme = base.textTheme.apply(
    fontFamily: palette.fontFamily ?? 'Roboto',
    fontSizeFactor: fontScale,
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
  );
  final appliedPrimaryTextTheme = base.primaryTextTheme.apply(
    fontFamily: palette.fontFamily ?? 'Roboto',
    fontSizeFactor: fontScale,
  );
  final textTheme = palette.id == AppThemeId.tienMonPremium
      ? _withTienMonTextShadows(appliedTextTheme)
      : appliedTextTheme;
  final primaryTextTheme = palette.id == AppThemeId.tienMonPremium
      ? _withTienMonTextShadows(appliedPrimaryTextTheme)
      : appliedPrimaryTextTheme;
  final premiumTextShadows = palette.id == AppThemeId.tienMonPremium
      ? tienMonTextShadows
      : null;
  return base.copyWith(
    scaffoldBackgroundColor: palette.surface,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          secondary: palette.accent,
          surface: palette.surface,
          onSurface: palette.textPrimary,
        ),
    textTheme: textTheme,
    primaryTextTheme: primaryTextTheme,
    iconTheme: IconThemeData(color: palette.textPrimary),
    cardTheme: CardThemeData(
      color: palette.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(palette.radius),
        side: BorderSide(color: palette.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.dark && palette.id != AppThemeId.lol
            ? Colors.white
            : palette.id == AppThemeId.lol
            ? const Color(0xFF06171D)
            : Colors.white,
        shape: shape,
        textStyle: TextStyle(
          fontFamily: palette.fontFamily ?? 'Roboto',
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w800,
          letterSpacing: themeLetterSpacing(palette),
          shadows: premiumTextShadows,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.border),
        shape: shape,
        textStyle: TextStyle(
          fontFamily: palette.fontFamily ?? 'Roboto',
          fontSize: 14 * fontScale,
          shadows: premiumTextShadows,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: TextStyle(
          fontFamily: palette.fontFamily ?? 'Roboto',
          fontSize: 14 * fontScale,
          shadows: premiumTextShadows,
        ),
      ),
    ),
    dividerColor: palette.border,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      modalBackgroundColor: palette.surface,
    ),
  );
}

/// Match a selected font's actual glyph footprint to the system font at the
/// same nominal size. Imported fonts can have very different advances/ascents.
double themeFontSizeFactor(String? family) {
  if (family == null || family.isEmpty || family == 'Roboto') return 1;
  const sample = 'Ngày 25/09 • Lịch học';
  Size measure(String font) {
    final painter = TextPainter(
      text: TextSpan(
        text: sample,
        style: TextStyle(fontFamily: font, fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.size;
  }

  final standard = measure('Roboto');
  final selected = measure(family);
  if (selected.width <= 0 || selected.height <= 0) return 1;
  final widthRatio = standard.width / selected.width;
  final heightRatio = standard.height / selected.height;
  return (widthRatio < heightRatio ? widthRatio : heightRatio).clamp(0.5, 1.1);
}

OutlinedBorder themeButtonShape(AppThemePalette palette) {
  return switch (palette.geometry) {
    AppThemeGeometry.valorant => const BeveledRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
    ),
    AppThemeGeometry.lol => const BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    AppThemeGeometry.pixel ||
    AppThemeGeometry.square => const RoundedRectangleBorder(),
    AppThemeGeometry.rounded => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(palette.radius),
    ),
  };
}

double themeLetterSpacing(AppThemePalette palette) => switch (palette.id) {
  AppThemeId.valorant => .85,
  AppThemeId.lol => .65,
  AppThemeId.minecraft => .15,
  AppThemeId.tienMonPremium => .2,
  _ => 0,
};

String themedHeading(String value, AppThemePalette palette) =>
    palette.id == AppThemeId.valorant ? value.toUpperCase() : value;

class AppThemeBackdrop extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<AppThemeBackdrop> createState() => _AppThemeBackdropState();
}

class _AppThemeBackdropState extends State<AppThemeBackdrop>
    with WidgetsBindingObserver {
  late final TienMonSceneController _tienMonScenes = TienMonSceneController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        appThemePalette.id == AppThemeId.tienMonPremium) {
      _tienMonScenes.useAutomatic();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tienMonScenes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (appThemePalette.id == AppThemeId.tienMonPremium) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TienMonPersistentBackground(controller: _tienMonScenes),
          TienMonPersistentAmbient(controller: _tienMonScenes),
          widget.child,
        ],
      );
    }
    return CustomPaint(
      painter: _ThemeBackdropPainter(appThemePalette),
      child: SizedBox.expand(child: widget.child),
    );
  }
}

class _ThemeBackdropPainter extends CustomPainter {
  const new(this.palette);

  final AppThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[palette.pageStart, palette.pageEnd],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    switch (palette.id) {
      case AppThemeId.minecraft:
        final block = (size.shortestSide / 11).clamp(26.0, 48.0);
        final paint = Paint();
        for (var y = 0.0; y < size.height; y += block) {
          for (var x = 0.0; x < size.width; x += block) {
            final index = ((x / block).floor() + (y / block).floor()) % 4;
            paint.color = <Color>[
              const Color(0xFF5A3824),
              const Color(0xFF6A4229),
              const Color(0xFF4C2D1C),
              const Color(0xFF765037),
            ][index];
            canvas.drawRect(Rect.fromLTWH(x, y, block + .5, block + .5), paint);
          }
        }
        paint.color = const Color(0xFF5D963E).withValues(alpha: .55);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, block * .28), paint);
      case AppThemeId.valorant:
        final paint = Paint()..color = palette.primary.withValues(alpha: .13);
        final path = Path()
          ..moveTo(size.width * .62, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height * .31)
          ..close();
        canvas.drawPath(path, paint);
        final path2 = Path()
          ..moveTo(0, size.height * .78)
          ..lineTo(size.width * .26, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path2, paint);
      case AppThemeId.lol:
        final glow = Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  palette.primary.withValues(alpha: .18),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(size.width * .5, size.height * .08),
                  radius: size.width * .55,
                ),
              );
        canvas.drawRect(rect, glow);
        final line = Paint()
          ..color = palette.accent.withValues(alpha: .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(
          Offset(size.width * .5, size.height * .12),
          size.width * .31,
          line,
        );
      case AppThemeId.tiktok:
        final pink = Paint()..color = palette.primary.withValues(alpha: .08);
        final cyan = Paint()..color = palette.accent.withValues(alpha: .07);
        canvas.drawCircle(
          Offset(size.width * .9, size.height * .18),
          size.width * .36,
          pink,
        );
        canvas.drawCircle(
          Offset(size.width * .05, size.height * .76),
          size.width * .3,
          cyan,
        );
      case AppThemeId.ben10:
        final ring = Paint()
          ..color = palette.accent.withValues(alpha: .10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10;
        canvas.drawCircle(
          Offset(size.width * .86, size.height * .12),
          size.width * .22,
          ring,
        );
      case AppThemeId.youtube:
        final glow = Paint()..color = palette.primary.withValues(alpha: .07);
        canvas.drawCircle(Offset(size.width * .52, 0), size.width * .55, glow);
      case AppThemeId.steam:
        final glow = Paint()
          ..shader = LinearGradient(
            colors: <Color>[
              Colors.transparent,
              palette.primary.withValues(alpha: .11),
            ],
          ).createShader(rect);
        canvas.drawRect(rect, glow);
      case AppThemeId.shopee:
        final band = Paint()..color = palette.primary.withValues(alpha: .10);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height * .14),
          band,
        );
      case AppThemeId.facebook:
      case AppThemeId.classic:
      case AppThemeId.tienMonPremium:
      case AppThemeId.custom:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeBackdropPainter oldDelegate) =>
      oldDelegate.palette.id != palette.id ||
      oldDelegate.palette.pageStart != palette.pageStart ||
      oldDelegate.palette.pageEnd != palette.pageEnd ||
      oldDelegate.palette.primary != palette.primary ||
      oldDelegate.palette.accent != palette.accent;
}

class AppThemePanel extends StatelessWidget {
  const new({
    required this.child,
    this.padding,
    this.width,
    this.constraints,
    this.alt = false,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BoxConstraints? constraints;
  final bool alt;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final decoration = BoxDecoration(
      color: alt ? palette.cardAlt : palette.card,
      border: Border.all(
        color: palette.border,
        width: palette.geometry == AppThemeGeometry.pixel ? 3 : 1,
      ),
      borderRadius: palette.geometry == AppThemeGeometry.rounded
          ? BorderRadius.circular(palette.radius)
          : BorderRadius.zero,
      boxShadow: elevated
          ? <BoxShadow>[
              BoxShadow(
                color: palette.shadow,
                blurRadius: palette.geometry == AppThemeGeometry.pixel ? 0 : 18,
                offset: palette.geometry == AppThemeGeometry.pixel
                    ? const Offset(4, 4)
                    : const Offset(0, 6),
              ),
            ]
          : null,
    );
    final box = Container(
      width: width,
      constraints: constraints,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    return switch (palette.geometry) {
      AppThemeGeometry.valorant => ClipPath(
        clipper: const _ValorantClipper(),
        child: box,
      ),
      AppThemeGeometry.lol => ClipPath(
        clipper: const _LolClipper(),
        child: box,
      ),
      _ => box,
    };
  }
}

class _ValorantClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    const cut = 12.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LolClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    const cut = 11.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
