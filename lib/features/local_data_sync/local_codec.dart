import 'dart:convert';

import 'package:better_phenikaa_schedule/core/contracts/models.dart';

/// Portable JSON for one atomic SharedPreferences cache entry.
/// SQLite/Drift migration can replace this codec without changing contracts.
class LocalCacheCodec {
  const LocalCacheCodec._();

  static String encode(QldtImportPayload data) => jsonEncode(<String, Object?>{
        'schema': 1,
        'syncedAt': data.syncedAt.toIso8601String(),
        'user': <String, String>{'studentId': data.user.studentId, 'displayName': data.user.displayName},
        'semester': <String, String>{'id': data.semester.id, 'name': data.semester.name, 'startDate': data.semester.startDate.toIso8601String(), 'endDate': data.semester.endDate.toIso8601String()},
        'classes': data.classes.map((e) => <String, String>{'id': e.id, 'subjectCode': e.subjectCode, 'subjectName': e.subjectName, 'room': e.room, 'lecturer': e.lecturer, 'startAt': e.startAt.toIso8601String(), 'endAt': e.endAt.toIso8601String()}).toList(),
        'exams': data.exams.map((e) => <String, String>{'id': e.id, 'subjectCode': e.subjectCode, 'subjectName': e.subjectName, 'room': e.room, 'startAt': e.startAt.toIso8601String(), 'endAt': e.endAt.toIso8601String()}).toList(),
      });

  static QldtImportPayload decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['schema'] != 1) throw const FormatException('Unsupported cache schema');
    final user = json['user'] as Map<String, dynamic>;
    final sem = json['semester'] as Map<String, dynamic>;
    final classes = (json['classes'] as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      return ClassDto(id: row['id'] as String, subjectCode: row['subjectCode'] as String, subjectName: row['subjectName'] as String, room: row['room'] as String, lecturer: row['lecturer'] as String, startAt: DateTime.parse(row['startAt'] as String), endAt: DateTime.parse(row['endAt'] as String));
    }).toList();
    final exams = (json['exams'] as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      return ExamDto(id: row['id'] as String, subjectCode: row['subjectCode'] as String, subjectName: row['subjectName'] as String, room: row['room'] as String, startAt: DateTime.parse(row['startAt'] as String), endAt: DateTime.parse(row['endAt'] as String));
    }).toList();
    return QldtImportPayload(
      user: UserDto(studentId: user['studentId'] as String, displayName: user['displayName'] as String),
      semester: SemesterDto(id: sem['id'] as String, name: sem['name'] as String, startDate: DateTime.parse(sem['startDate'] as String), endDate: DateTime.parse(sem['endDate'] as String)),
      classes: classes, exams: exams, syncedAt: DateTime.parse(json['syncedAt'] as String),
    );
  }
}
