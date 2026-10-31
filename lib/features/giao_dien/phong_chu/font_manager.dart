import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tep_cuc_bo/file_bytes.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tep_cuc_bo/local_file_bridge.dart';
import 'package:flutter/services.dart';

final class ThemeFontManager {
  new _();

  static final ThemeFontManager instance = ThemeFontManager._();
  static const int _maximumFontBytes = 12 * 1024 * 1024;

  final Set<String> _loadedFamilies = <String>{};

  Future<AppFontChoice?> importFont() async {
    final file = await LocalFileBridge.pick(LocalFileKind.font);
    if (file == null) {
      return null;
    }
    final bytes = await readManagedFile(
      file.path,
      maximumBytes: _maximumFontBytes,
    );
    validateFontBytes(bytes);
    final family = 'ImportedThemeFont_${_hash(bytes)}';
    await _load(family, bytes);
    return AppFontChoice(
      id: 'imported:$family',
      label: file.name,
      kind: AppFontKind.imported,
      family: family,
      path: file.path,
      fileName: file.name,
    );
  }

  /// Returns null when an imported file disappeared or cannot be registered.
  Future<String?> resolveFamily(AppFontChoice choice) async {
    if (choice.kind != AppFontKind.imported) {
      return choice.family;
    }
    final path = choice.path;
    final family = choice.family;
    if (path == null || family == null || !await managedFileExists(path)) {
      return null;
    }
    try {
      final bytes = await readManagedFile(
        path,
        maximumBytes: _maximumFontBytes,
      );
      validateFontBytes(bytes);
      await _load(family, bytes);
      return family;
    } on Object {
      return null;
    }
  }

  Future<void> _load(String family, Uint8List bytes) async {
    if (!_loadedFamilies.add(family)) {
      return;
    }
    try {
      final loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
    } on Object {
      _loadedFamilies.remove(family);
      rethrow;
    }
  }

  static void validateFontBytes(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const FormatException('Font quá nhỏ hoặc bị hỏng.');
    }
    final header = ByteData.sublistView(bytes).getUint32(0);
    const accepted = <int>{
      0x00010000, // TrueType
      0x4F54544F, // OTTO / OpenType CFF
      0x74727565, // true
      0x74797031, // typ1
    };
    if (!accepted.contains(header)) {
      throw const FormatException('Chỉ hỗ trợ font TTF hoặc OTF hợp lệ.');
    }
  }

  static String _hash(Uint8List bytes) {
    var value = 0x811C9DC5;
    for (final byte in bytes) {
      value ^= byte;
      value = (value * 0x01000193) & 0xFFFFFFFF;
    }
    return value.toRadixString(16).padLeft(8, '0');
  }
}
