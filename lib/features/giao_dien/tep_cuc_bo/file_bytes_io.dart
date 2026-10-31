import 'dart:io';
import 'dart:typed_data';

/// Đọc có giới hạn để file lỗi không làm cạn bộ nhớ.
Future<Uint8List> readManagedFile(
  String path, {
  required int maximumBytes,
}) async {
  final file = File(path);
  final length = await file.length();
  if (length <= 0 || length > maximumBytes) {
    throw FormatException(
      'Tệp phải lớn hơn 0 byte và không vượt quá '
      '${(maximumBytes / (1024 * 1024)).floor()} MB.',
    );
  }
  return await file.readAsBytes();
}

Future<bool> managedFileExists(String path) =>
    Future<bool>.value(File(path).existsSync());
