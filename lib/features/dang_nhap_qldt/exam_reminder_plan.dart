import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class ExamReminder {
  const new({
    required this.key,
    required this.subjectId,
    required this.daysBefore,
    required this.at,
  });

  final String key;
  final String subjectId;
  final int daysBefore;
  final DateTime at;
}

final class ExamReminderPlan {
  const new({required this.schedule, required this.cancelKeys});

  final List<ExamReminder> schedule;
  final Set<String> cancelKeys;
}

final class ExamReminderPlanner {
  const new();

  ExamReminderPlan plan({
    required CurrentSemester semester,
    required DateTime now,
    required Set<String> scheduledKeys,
    required Set<String> deliveredKeys,
  }) {
    final future = <String, ExamReminder>{};
    for (final subject in semester.subjects) {
      for (final exam in subject.examSchedules) {
        final examKey =
            '${subject.subjectId}|${exam.startAt.toIso8601String()}|${exam.endAt.toIso8601String()}|${exam.room.trim().toLowerCase()}|${normalizeSubjectName(exam.className)}|${normalizeSubjectName(exam.examForm)}';
        for (final days in const <int>[7, 3, 1]) {
          final at = exam.startAt.subtract(Duration(days: days));
          if (!at.isAfter(now)) continue;
          final key = '$examKey|$days';
          if (deliveredKeys.contains(key)) continue;
          future[key] = ExamReminder(
            key: key,
            subjectId: subject.subjectId,
            daysBefore: days,
            at: at,
          );
        }
      }
    }
    return ExamReminderPlan(
      schedule: future.values
          .where((item) => !scheduledKeys.contains(item.key))
          .toList(),
      cancelKeys: scheduledKeys.difference(future.keys.toSet()),
    );
  }
}
