import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

DateTime semesterExpiry(DateTime startedAt) {
  final targetMonth = DateTime(startedAt.year, startedAt.month + 4);
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  final day = startedAt.day < lastDay ? startedAt.day : lastDay;
  return DateTime(targetMonth.year, targetMonth.month, day + 7);
}

/// Personal term window, based on the earliest registered class.
final class SemesterScheduleRange {
  const new(this.start, this.end);

  final DateTime start;
  final DateTime end;

  static SemesterScheduleRange? fromRegistration(
    RegisteredSemester registration,
  ) {
    final sections = registration.classSections.values
        .expand((classes) => classes)
        .toList();
    if (sections.isEmpty) return null;
    final first = sections
        .map((section) => section.startsOn)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return SemesterScheduleRange(
      DateTime(first.year, first.month, first.day),
      semesterExpiry(first),
    );
  }
}
