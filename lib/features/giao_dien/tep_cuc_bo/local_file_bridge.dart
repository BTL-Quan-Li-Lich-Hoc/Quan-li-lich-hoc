import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LocalFileKind { image, font }

@immutable
final class ManagedLocalFile {
  const new({
    required this.path,
    required this.name,
    required this.size,
    required this.mimeType,
  });

  final String path;
  final String name;
  final int size;
  final String mimeType;
}

/// Cầu Android Storage Access Framework. Tệp được sao chép vào vùng private của
/// app's private storage by native code and never uploaded.
abstract final class LocalFileBridge {
  static const MethodChannel _channel = MethodChannel(
    'better_phenikaa/local_files',
  );

  static Future<ManagedLocalFile?> pick(LocalFileKind kind) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final value = await _channel.invokeMapMethod<String, Object?>(
      'pickFile',
      <String, Object>{'kind': kind.name},
    );
    if (value == null) {
      return null;
    }
    final path = value['path'];
    final name = value['name'];
    final size = value['size'];
    if (path is! String || name is! String || size is! num) {
      throw const FormatException('Tệp được chọn không hợp lệ.');
    }
    return ManagedLocalFile(
      path: path,
      name: name,
      size: size.toInt(),
      mimeType: value['mimeType'] as String? ?? '',
    );
  }
}
