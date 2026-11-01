import 'dart:typed_data';

/// Fallback cho nền tảng không có file system riêng của app.
Future<Uint8List> readManagedFile(String path, {required int maximumBytes}) =>
    Future<Uint8List>.error(
      UnsupportedError('Đọc tệp cục bộ không được hỗ trợ trên nền tảng này.'),
    );

Future<bool> managedFileExists(String path) => Future<bool>.value(false);
