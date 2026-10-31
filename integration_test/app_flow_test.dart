import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('day, week and exam views use the restored schedule', (
    tester,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 7);
    final exam = now.add(const Duration(days: 10));
    final data = ImportedScheduleData(
      displayName: 'Sinh viên mô phỏng',
      records: <ScheduleRecord>[
        ScheduleRecord(
          id: 'study',
          isExam: false,
          subjectName: 'Thiết kế web nâng cao',
          room: 'A1',
          startAt: start,
          endAt: start.add(const Duration(hours: 2)),
        ),
        ScheduleRecord(
          id: 'exam',
          isExam: true,
          subjectName: 'Thiết kế web nâng cao',
          room: 'C3',
          startAt: DateTime(exam.year, exam.month, exam.day, 8),
          endAt: DateTime(exam.year, exam.month, exam.day, 10),
        ),
      ],
      syncedAt: now,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_snapshot_v1': data.encode(),
    });
    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 12 && find.text('Thiết kế web nâng cao').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Theo ngày'), findsOneWidget);
    expect(
      find.text('Thiết kế web nâng cao'),
      findsWidgets,
      reason: find
          .byType(Text)
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .join(' | '),
    );

    await tester.tap(find.text('Theo tuần'));
    await tester.pumpAndSettle();
    final weekScroll = find
        .descendant(
          of: find.byType(WeekTimetable),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Thiết kế web nâng cao'),
      160,
      scrollable: weekScroll,
      maxScrolls: 7,
    );
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tuần trước'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thiết kế web nâng cao'),
      160,
      scrollable: weekScroll,
      maxScrolls: 7,
    );
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);

    await tester.tap(find.text('Theo ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch thi'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);
  });
}
