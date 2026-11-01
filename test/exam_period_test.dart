import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/exam_period.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 26, 10);
  ScheduleRecord exam(DateTime start, DateTime end) => ScheduleRecord(
    id: 'exam',
    isExam: true,
    subjectName: 'Toán',
    room: 'A1',
    startAt: start,
    endAt: end,
  );

  test('period follows the final endAt and an empty list is inactive', () {
    expect(ExamPeriod.hasActiveExamPeriod(<ScheduleRecord>[], now), isFalse);
    final finished = exam(DateTime(2026, 9, 25, 8), DateTime(2026, 9, 25, 10));
    final future = exam(DateTime(2026, 9, 27, 8), DateTime(2026, 9, 27, 10));
    expect(
      ExamPeriod.hasActiveExamPeriod(<ScheduleRecord>[finished], now),
      isFalse,
    );
    expect(
      ExamPeriod.hasActiveExamPeriod(<ScheduleRecord>[finished, future], now),
      isTrue,
    );
    final today = exam(DateTime(2026, 9, 26, 8), DateTime(2026, 9, 26, 11));
    expect(
      ExamPeriod.hasActiveExamPeriod(<ScheduleRecord>[today], now),
      isTrue,
    );
    expect(
      ExamPeriod.hasActiveExamPeriod(<ScheduleRecord>[today], today.endAt),
      isTrue,
    );
    expect(
      ExamPeriod.hasActiveExamPeriod(<ScheduleRecord>[
        today,
      ], today.endAt.add(const Duration(milliseconds: 1))),
      isFalse,
    );
  });

  for (final (days, label, band) in <(int, String, ExamCountdownBand)>[
    (20, 'Còn 20 ngày', ExamCountdownBand.green),
    (10, 'Còn 10 ngày', ExamCountdownBand.blue),
    (5, 'Còn 5 ngày', ExamCountdownBand.orange),
    (2, 'Còn 2 ngày', ExamCountdownBand.red),
    (1, 'Ngày mai', ExamCountdownBand.red),
    (0, 'Hôm nay', ExamCountdownBand.red),
  ]) {
    test('countdown $days days uses $label and $band', () {
      final start = DateTime(now.year, now.month, now.day + days, 11);
      final result = ExamPeriod.countdown(
        exam(start, start.add(const Duration(hours: 2))),
        now,
      );
      expect(result?.label, label);
      expect(result?.band, band);
    });
  }

  test('no countdown after endAt even when exam date is today', () {
    final ended = exam(DateTime(2026, 9, 26, 7), DateTime(2026, 9, 26, 9));
    expect(ExamPeriod.countdown(ended, now), isNull);
  });
}
