import 'package:better_phenikaa_schedule/core/contracts/models.dart';

/// Pure timetable/exam business logic, independent of widgets and persistence.
class ScheduleQueries {
  const ScheduleQueries._();

  static String normalizeSubject(String text) {
    return text
        .trim()
        .replaceFirst(RegExp(r'^Môn\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<ClassDto> onDay(List<ClassDto> classes, DateTime day) {
    final matches = classes
        .where(
          (c) =>
              c.startAt.year == day.year &&
              c.startAt.month == day.month &&
              c.startAt.day == day.day,
        )
        .toList();
    matches.sort((a, b) => a.startAt.compareTo(b.startAt));
    return matches;
  }

  static List<ClassDto> inWeek(List<ClassDto> classes, DateTime day) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: day.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final matches = classes
        .where((c) => !c.startAt.isBefore(start) && c.startAt.isBefore(end))
        .toList();
    matches.sort((a, b) => a.startAt.compareTo(b.startAt));
    return matches;
  }

  static List<ExamDto> upcomingExams(List<ExamDto> exams, DateTime now) {
    final matches = exams.where((e) => !e.endAt.isBefore(now)).toList();
    matches.sort((a, b) => a.startAt.compareTo(b.startAt));
    return matches;
  }
}
