import 'dart:convert';

/// Raw data transport boundary. Does not log credentials or store cookies.
class QldtRawDocument {
  const QldtRawDocument(this.text);

  final String text;

  factory QldtRawDocument.fromJsonText(String input) {
    final parsed = jsonDecode(input);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu lịch học phải là một JSON object.');
    }
    final rows = parsed['Data'] ?? parsed['schedule'] ?? parsed['rows'];
    if (rows is! List) {
      throw const FormatException('Không tìm thấy danh sách Data / schedule / rows.');
    }
    if (rows.length > 10000) {
      throw const FormatException('Tệp lịch học có quá nhiều bản ghi.');
    }
    return QldtRawDocument(input);
  }
}
