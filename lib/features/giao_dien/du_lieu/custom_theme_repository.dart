import 'dart:convert';

import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class CustomThemeRepository {
  const new();

  static const _storageKey = 'better_phenikaa_custom_themes_v1';

  Future<List<CustomThemeDefinition>> readAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <CustomThemeDefinition>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <CustomThemeDefinition>[];
      }
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (value) => CustomThemeDefinition.fromJson(
              Map<String, Object?>.from(value),
            ),
          )
          .toList(growable: false);
    } on Object {
      return <CustomThemeDefinition>[];
    }
  }

  Future<void> replaceAll(List<CustomThemeDefinition> themes) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(themes.map((theme) => theme.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('Không thể lưu theme trên thiết bị.');
    }
  }
}
