import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_range.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class RetainedSemester {
  const new(this.semester, this.startedAt);

  factory decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return RetainedSemester(
      CurrentSemester.fromJson(
        Map<String, dynamic>.from(json['semester'] as Map),
      ),
      DateTime.parse(json['startedAt'] as String),
    );
  }

  final CurrentSemester semester;
  final DateTime startedAt;

  DateTime get expiresOn => semesterExpiry(startedAt);

  bool activeAt(DateTime now) => now.isBefore(
    DateTime(expiresOn.year, expiresOn.month, expiresOn.day + 1),
  );

  String encode() => jsonEncode(<String, Object?>{
    'startedAt': startedAt.toIso8601String(),
    'semester': semester.toJson(),
  });
}

abstract final class SemesterRetention {
  static const currentStartKey = 'better_phenikaa_current_term_start_v1';
  static const previousKey = 'better_phenikaa_previous_semester_v1';

  static DateTime? startOf(CurrentSemester semester, String? saved) {
    if (saved != null) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null) return parsed;
    }
    // Data stored before the term-start key existed can only use its first
    // verified lesson as an approximate personal start date.
    final lessons = semester.subjects
        .expand((subject) => subject.studySchedules)
        .map((row) => row.startAt)
        .toList();
    if (lessons.isEmpty) return null;
    lessons.sort();
    final first = lessons.first;
    return DateTime(first.year, first.month, first.day);
  }

  static ImportedScheduleData combine(
    CurrentSemester current,
    RetainedSemester? previous,
  ) {
    final data = current.toImportedScheduleData();
    final old = previous?.semester.toImportedScheduleData();
    if (old == null) return data;
    final records = <ScheduleRecord>[...old.records, ...data.records]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return ImportedScheduleData(
      displayName: data.displayName.isEmpty
          ? old.displayName
          : data.displayName,
      records: records,
      syncedAt: data.syncedAt,
    );
  }

  static RetainedSemester? readPrevious(SharedPreferences prefs, DateTime now) {
    final raw = prefs.getString(previousKey);
    if (raw == null) return null;
    try {
      final previous = RetainedSemester.decode(raw);
      return previous.activeAt(now) ? previous : null;
    } on Object {
      return null;
    }
  }
}
