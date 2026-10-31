import 'dart:convert';

import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/timetable/domain/schedule_queries.dart';

/// Validates QLDT-shaped JSON and returns the frozen cross-team DTO contract.
class QldtScheduleParser {
  const QldtScheduleParser._();

  static QldtImportPayload parse(String text, {DateTime? receivedAt}) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>)
      throw const FormatException('Expected a JSON object');
    final raw = decoded['Data'] ?? decoded['schedule'] ?? decoded['rows'];
    if (raw is! List) throw const FormatException('Missing Data/schedule/rows');
    if (raw.length > 10000) throw const FormatException('Too many records');
    final classes = <ClassDto>[];
    final exams = <ExamDto>[];
    for (var index = 0; index < raw.length; index++) {
      final row = raw[index];
      if (row is! Map) throw FormatException('Row $index is not an object');
      final source = row.map((k, v) => MapEntry(k.toString(), v));
      final name = ScheduleQueries.normalizeSubject(
        _string(source, ['TENHOCPHAN', 'subjectName', 'TENMONHOC']),
      );
      if (name.isEmpty) throw FormatException('Row $index has no subject');
      final start = _date(source, ['startAt', 'NGAYHOC', 'NGAYTHI'], index);
      final hour = _number(source, ['GIOBATDAU'], 0);
      final minute = _number(source, ['PHUTBATDAU'], 0);
      final startAt = source.containsKey('startAt')
          ? start
          : DateTime(start.year, start.month, start.day, hour, minute);
      final endDate = source.containsKey('endAt')
          ? _date(source, ['endAt'], index)
          : null;
      final endAt =
          endDate ??
          DateTime(
            startAt.year,
            startAt.month,
            startAt.day,
            _number(source, ['GIOKETTHUC'], startAt.hour + 1),
            _number(source, ['PHUTKETTHUC'], startAt.minute),
          );
      if (!endAt.isAfter(startAt))
        throw FormatException('Row $index invalid time range');
      final kind = _string(source, ['PHANLOAI', 'type']).toUpperCase();
      final code = _string(source, [
        'TENLOPHOCPHAN',
        'subjectCode',
        'MAHOCPHAN',
      ]);
      final id = _string(source, ['ID', 'id']).isEmpty
          ? '$index-$code-${startAt.toIso8601String()}'
          : _string(source, ['ID', 'id']);
      final room = _string(source, ['PHONGHOC_TEN', 'PHONGTHI', 'room']);
      if (kind == 'LICHTHI' || kind == 'EXAM') {
        exams.add(
          ExamDto(
            id: id,
            subjectCode: code,
            subjectName: name,
            room: room,
            startAt: startAt,
            endAt: endAt,
          ),
        );
      } else {
        classes.add(
          ClassDto(
            id: id,
            subjectCode: code,
            subjectName: name,
            room: room,
            lecturer: _string(source, ['GIANGVIEN', 'lecturer']),
            startAt: startAt,
            endAt: endAt,
          ),
        );
      }
    }
    classes.sort((a, b) => a.startAt.compareTo(b.startAt));
    exams.sort((a, b) => a.startAt.compareTo(b.startAt));
    final date = receivedAt ?? DateTime.now();
    final user = decoded['user'];
    final userMap = user is Map ? user : const <String, Object>{};
    final semester = decoded['semester'];
    final sem = semester is Map ? semester : const <String, Object>{};
    final starts = <DateTime>[
      ...classes.map((e) => e.startAt),
      ...exams.map((e) => e.startAt),
    ]..sort();
    final ends = <DateTime>[
      ...classes.map((e) => e.endAt),
      ...exams.map((e) => e.endAt),
    ]..sort();
    final semStart = sem['startDate'] == null
        ? (starts.isEmpty ? DateTime(date.year, 1, 1) : starts.first)
        : DateTime.parse(sem['startDate'].toString());
    final semEnd = sem['endDate'] == null
        ? (ends.isEmpty ? DateTime(date.year, 12, 31) : ends.last)
        : DateTime.parse(sem['endDate'].toString());
    return QldtImportPayload(
      user: UserDto(
        studentId: (userMap['studentId'] ?? 'demo').toString(),
        displayName: (userMap['displayName'] ?? 'Sinh viên').toString(),
      ),
      semester: SemesterDto(
        id: (sem['id'] ?? 'current').toString(),
        name: (sem['name'] ?? 'Học kỳ hiện tại').toString(),
        startDate: semStart,
        endDate: semEnd,
      ),
      classes: List<ClassDto>.unmodifiable(classes),
      exams: List<ExamDto>.unmodifiable(exams),
      syncedAt: date,
    );
  }

  static String _string(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final text = row[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static int _number(
    Map<String, dynamic> row,
    List<String> keys,
    int fallback,
  ) {
    for (final key in keys) {
      final value = int.tryParse(row[key]?.toString() ?? '');
      if (value != null) return value;
    }
    return fallback;
  }

  static DateTime _date(
    Map<String, dynamic> row,
    List<String> keys,
    int index,
  ) {
    final value = _string(row, keys);
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final vn = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
    if (vn != null) {
      final d = int.parse(vn.group(1)!);
      final m = int.parse(vn.group(2)!);
      final y = int.parse(vn.group(3)!);
      final result = DateTime(y, m, d);
      if (result.day == d && result.month == m && result.year == y)
        return result;
    }
    throw FormatException('Row $index has invalid date: $value');
  }
}
