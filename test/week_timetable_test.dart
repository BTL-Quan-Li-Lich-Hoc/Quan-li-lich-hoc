import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScheduleRecord row(String name, int day, int hour) => ScheduleRecord(
    id: '$name|$day|$hour',
    isExam: false,
    subjectName: name,
    room: 'A1',
    startAt: DateTime(2026, 9, day, hour),
    endAt: DateTime(2026, 9, day, hour + 2),
  );

  test('week starts on Monday, including across month boundaries', () {
    expect(weekMonday(DateTime(2026, 10, 1)), DateTime(2026, 9, 28));
    expect(weekMonday(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
  });

  testWidgets('compact week keeps empty rows and scrolls extra classes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = ImportedScheduleData(
      displayName: 'Sinh viên',
      records: <ScheduleRecord>[
        for (var i = 0; i < 6; i++) row('Môn $i', 28, 7 + i),
      ],
      syncedAt: DateTime(2026, 9, 28),
    );
    DateTime? changed;
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekTimetable(
            data: data,
            week: DateTime(2026, 9, 29),
            onWeekChanged: (date) => changed = date,
            onPickWeek: () => picked = true,
          ),
        ),
      ),
    );
    expect(find.text('28/09 – 04/10'), findsOneWidget);
    expect(find.text('Môn 0'), findsOneWidget);
    expect(find.text('6 buổi'), findsOneWidget);
    expect(find.text('Không có lịch học'), findsWidgets);
    await tester.tap(find.byTooltip('Tuần sau'));
    expect(changed, DateTime(2026, 10, 5));
    await tester.tap(find.text('28/09 – 04/10'));
    expect(picked, isTrue);
    expect(tester.takeException(), isNull);
  });
}
