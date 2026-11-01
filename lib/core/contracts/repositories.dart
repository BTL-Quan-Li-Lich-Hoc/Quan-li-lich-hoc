import 'dart:convert';

import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class QldtIntakeRepository {
  Future<bool> hasValidSession();

  Future<QldtImportPayload> sync();

  Future<void> clearSession();
}

abstract interface class ScheduleRepository {
  Stream<List<ClassDto>> watchRange({
    required DateTime from,
    required DateTime to,
  });

  Future<void> replaceFromImport(QldtImportPayload payload);

  Future<void> clearAll();
}

abstract interface class ExamRepository {
  Stream<List<ExamDto>> watchAll();

  Future<void> replaceFromImport(QldtImportPayload payload);

  Future<void> clearAll();
}

abstract interface class WidgetSnapshotRepository {
  Future<WidgetSnapshot?> read();

  Future<void> write(WidgetSnapshot? snapshot);

  Future<void> clear();
}


/// Bộ nhớ lịch cục bộ khi không có mạng; chỉ ghi sau khi xác minh dữ liệu.
/// Không lưu mật khẩu, cookie hoặc token đăng nhập.
final class QldtLocalCache {
  const QldtLocalCache();

  static const String _key = 'bpa.local.schedule.v1';

  Future<QldtImportPayload?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic>) return null;
      final student = Map<String, dynamic>.from(data['user'] as Map);
      final term = Map<String, dynamic>.from(data['semester'] as Map);
      final classes = data['classes'] as List;
      final exams = data['exams'] as List;
      if (classes.length + exams.length > 10000) return null;

      final result = QldtImportPayload(
        user: UserDto(
          studentId: student['studentId'] as String,
          displayName: student['displayName'] as String,
        ),
        semester: SemesterDto(
          id: term['id'] as String,
          name: term['name'] as String,
          startDate: DateTime.parse(term['startDate'] as String),
          endDate: DateTime.parse(term['endDate'] as String),
        ),
        classes: List<ClassDto>.unmodifiable(classes.map((entry) {
          final row = Map<String, dynamic>.from(entry as Map);
          return ClassDto(
            id: row['id'] as String,
            subjectCode: row['subjectCode'] as String,
            subjectName: row['subjectName'] as String,
            room: row['room'] as String,
            lecturer: row['lecturer'] as String,
            startAt: DateTime.parse(row['startAt'] as String),
            endAt: DateTime.parse(row['endAt'] as String),
          );
        })),
        exams: List<ExamDto>.unmodifiable(exams.map((entry) {
          final row = Map<String, dynamic>.from(entry as Map);
          return ExamDto(
            id: row['id'] as String,
            subjectCode: row['subjectCode'] as String,
            subjectName: row['subjectName'] as String,
            room: row['room'] as String,
            startAt: DateTime.parse(row['startAt'] as String),
            endAt: DateTime.parse(row['endAt'] as String),
          );
        })),
        syncedAt: DateTime.parse(data['syncedAt'] as String),
      );
      _validate(result);
      return result;
    } on Object {
      // Dữ liệu cũ hỏng không làm ứng dụng bị crash.
      return null;
    }
  }

  Future<void> save(QldtImportPayload payload) async {
    _validate(payload);
    final data = <String, Object?>{
      'user': <String, String>{
        'studentId': payload.user.studentId,
        'displayName': payload.user.displayName,
      },
      'semester': <String, String>{
        'id': payload.semester.id,
        'name': payload.semester.name,
        'startDate': payload.semester.startDate.toIso8601String(),
        'endDate': payload.semester.endDate.toIso8601String(),
      },
      'classes': payload.classes.map((item) => <String, String>{
        'id': item.id,
        'subjectCode': item.subjectCode,
        'subjectName': item.subjectName,
        'room': item.room,
        'lecturer': item.lecturer,
        'startAt': item.startAt.toIso8601String(),
        'endAt': item.endAt.toIso8601String(),
      }).toList(growable: false),
      'exams': payload.exams.map((item) => <String, String>{
        'id': item.id,
        'subjectCode': item.subjectCode,
        'subjectName': item.subjectName,
        'room': item.room,
        'startAt': item.startAt.toIso8601String(),
        'endAt': item.endAt.toIso8601String(),
      }).toList(growable: false),
      'syncedAt': payload.syncedAt.toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(data))) {
      throw StateError('Không lưu được lịch offline.');
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static void _validate(QldtImportPayload payload) {
    if (payload.user.studentId.trim().isEmpty ||
        payload.semester.id.trim().isEmpty ||
        payload.semester.endDate.isBefore(payload.semester.startDate) ||
        payload.classes.length + payload.exams.length > 10000) {
      throw const FormatException('Thông tin sinh viên hoặc học kỳ không hợp lệ.');
    }
    for (final item in payload.classes) {
      if (item.id.isEmpty ||
          item.subjectName.trim().isEmpty ||
          !item.endAt.isAfter(item.startAt)) {
        throw const FormatException('Lịch học không hợp lệ.');
      }
    }
    for (final item in payload.exams) {
      if (item.id.isEmpty ||
          item.subjectName.trim().isEmpty ||
          !item.endAt.isAfter(item.startAt)) {
        throw const FormatException('Lịch thi không hợp lệ.');
      }
    }
  }
}
