import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';

enum ExamCountdownBand { green, blue, orange, red }

final class ExamCountdown {
  const new({required this.label, required this.band});

  final String label;
  final ExamCountdownBand band;
}

abstract final class ExamPeriod {
  static bool hasActiveExamPeriod(
    Iterable<ScheduleRecord> exams,
    DateTime now,
  ) => exams.any((exam) => !exam.endAt.isBefore(now));

  static ExamCountdown? countdown(ScheduleRecord exam, DateTime now) {
    if (exam.endAt.isBefore(now)) return null;
    final start = exam.startAt.toLocal();
    final today = now.toLocal();
    final examDay = DateTime.utc(start.year, start.month, start.day);
    final currentDay = DateTime.utc(today.year, today.month, today.day);
    final days = examDay.difference(currentDay).inDays;
    final label = days <= 0
        ? 'Hôm nay'
        : days == 1
        ? 'Ngày mai'
        : 'Còn $days ngày';
    final band = days > 15
        ? ExamCountdownBand.green
        : days > 7
        ? ExamCountdownBand.blue
        : days > 3
        ? ExamCountdownBand.orange
        : ExamCountdownBand.red;
    return ExamCountdown(label: label, band: band);
  }
}
