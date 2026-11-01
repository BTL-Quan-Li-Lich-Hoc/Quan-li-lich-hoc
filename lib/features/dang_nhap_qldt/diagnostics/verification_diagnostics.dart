import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class VerificationDiagnostics {
  const new();

  String captureRegistrationScope(String raw) {
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final registrations = payload['registrations'];
    final rows = registrations is Map ? registrations['Data'] : null;
    if (rows is! List) {
      return jsonEncode(<String, Object?>{
        'version': 1,
        'kind': 'registration_scope',
        'rowsAvailable': false,
      });
    }
    final planIds = <String>{};
    final semesterIds = <String>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final plan = row['DANGKY_KEHOACHDANGKY_ID'];
      final semester = row['DAOTAO_THOIGIANDAOTAO_ID'];
      if (plan is String && RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(plan)) {
        planIds.add(plan);
      }
      if (semester is String &&
          RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(semester)) {
        semesterIds.add(semester);
      }
    }
    return jsonEncode(<String, Object?>{
      'version': 1,
      'kind': 'registration_scope',
      'rowCount': rows.length,
      'distinctPlanIdCount': planIds.length,
      'planIds': planIds.take(10).toList(),
      'distinctSemesterIdCount': semesterIds.length,
      'semesterIds': semesterIds.take(10).toList(),
    });
  }

  String capture({
    required RegisteredSemester registration,
    required ImportedScheduleData schedule,
  }) {
    final issues = <Map<String, Object?>>[];
    var unrelatedSubjects = 0;
    var matchedRecords = 0;
    for (final record in schedule.records) {
      final subjectKey = normalizeSubjectName(record.subjectName);
      final subjectName = registration.subjectNames.where(
        (name) => normalizeSubjectName(name) == subjectKey,
      );
      if (subjectName.isEmpty) {
        unrelatedSubjects++;
        continue;
      }
      matchedRecords++;
      final sections =
          registration.classSections[subjectName.first] ??
          const <RegisteredClassSection>[];
      final classKey = normalizeSubjectName(record.className);
      final matching = sections.where(
        (section) => normalizeSubjectName(section.name) == classKey,
      );
      String? issue;
      if (classKey.isEmpty) {
        issue = 'schedule_class_empty';
      } else if (matching.isEmpty) {
        issue = 'class_name_mismatch';
      } else if (record.isExam &&
          record.startAt.isBefore(
            sections
                .map((section) => section.startsOn)
                .reduce((a, b) => a.isBefore(b) ? a : b),
          )) {
        issue = 'exam_before_registration';
      } else if (!record.isExam) {
        final day = DateTime(
          record.startAt.year,
          record.startAt.month,
          record.startAt.day,
        );
        final section = matching.first;
        if (day.isBefore(section.startsOn) || day.isAfter(section.endsOn)) {
          issue = 'study_outside_class_dates';
        }
      }
      if (issue != null && issues.length < 20) {
        issues.add(<String, Object?>{
          'reason': issue,
          'isExam': record.isExam,
          'subject': _safe(record.subjectName),
          'scheduleClass': _safe(record.className),
          'registeredClasses': sections
              .take(12)
              .map((section) => _safe(section.name))
              .toList(),
          'scheduleDate': _date(record.startAt),
          'matchedClassStart': matching.isEmpty
              ? null
              : _date(matching.first.startsOn),
          'matchedClassEnd': matching.isEmpty
              ? null
              : _date(matching.first.endsOn),
        });
      }
    }
    return jsonEncode(<String, Object?>{
      'version': 1,
      'kind': 'verification',
      'registeredSubjectCount': registration.subjectNames.length,
      'scheduleRecordCount': schedule.records.length,
      'unrelatedSubjectRecords': unrelatedSubjects,
      'matchedSubjectRecords': matchedRecords,
      'issues': issues,
    });
  }

  String _safe(String value) {
    if (RegExp(
      'token|cookie|authorization|session|bearer|password',
      caseSensitive: false,
    ).hasMatch(value)) {
      return '[redacted]';
    }
    final trimmed = value.trim();
    return trimmed
        .substring(0, trimmed.length > 100 ? 100 : trimmed.length)
        .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
        .replaceAll(RegExp(r'(?:\+?\d[\d\s.-]{6,}\d)'), '[number]');
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
