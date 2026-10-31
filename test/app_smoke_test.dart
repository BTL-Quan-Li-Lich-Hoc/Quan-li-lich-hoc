import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots into the official QLDT login flow', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const BetterPhenikaaScheduleApp());

    expect(find.text('Better Phenikaa App'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Chào mừng bạn!'), findsOneWidget);
    expect(find.textContaining('Đăng nhập QLĐT'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('mockup'), findsNothing);
  });

  testWidgets(
    'stored schedule opens day and week views without changing navigation',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final today = DateTime.now();
      final snapshot = ImportedScheduleData(
        displayName: 'Sinh viên',
        records: <ScheduleRecord>[
          ScheduleRecord(
            id: 'one',
            isExam: false,
            subjectName: 'Thiết kế web nâng cao',
            room: 'A1',
            startAt: DateTime(today.year, today.month, today.day, 7),
            endAt: DateTime(today.year, today.month, today.day, 9),
          ),
        ],
        syncedAt: today,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'better_phenikaa_snapshot_v1': snapshot.encode(),
      });
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Theo ngày'), findsOneWidget);
      expect(find.text('Theo tuần'), findsOneWidget);
      await tester.tap(find.text('Theo tuần'));
      await tester.pumpAndSettle();
      // The seven-day list builds only visible days; Friday can start below
      // the test viewport even though the record belongs to this week.
      final week = find.byType(WeekTimetable);
      final weekSubject = find.descendant(
        of: week,
        matching: find.text('Thiết kế web nâng cao'),
      );
      await tester.scrollUntilVisible(
        weekSubject,
        100,
        scrollable: find
            .descendant(of: week, matching: find.byType(Scrollable))
            .first,
      );
      expect(weekSubject, findsOneWidget);
      await tester.tap(find.byTooltip('Tuần sau'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final fades = tester.widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(WeekTimetable),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(
        fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(WeekTimetable),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(weekSubject, findsNothing);
      await tester.tap(find.text('Theo ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Thiết kế web nâng cao'), findsAtLeastNWidgets(1));
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('restores subject database through the legacy view adapter', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final today = DateTime.now();
    final semester = const SemesterDataBuilder().build(
      registration: const RegisteredSemester(
        id: '2026_2027_1',
        name: '2026_2027_1',
        subjectNames: <String>['Thiết kế web nâng cao'],
      ),
      studySchedules: <ScheduleRecord>[
        ScheduleRecord(
          id: 'class',
          isExam: false,
          subjectName: 'Thiết kế web nâng cao',
          room: 'A1',
          startAt: DateTime(today.year, today.month, today.day, 7),
          endAt: DateTime(today.year, today.month, today.day, 9),
        ),
      ],
      examSchedules: const <ScheduleRecord>[],
      displayName: 'Sinh viên',
      syncedAt: today,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_current_semester_v1': semester.encode(),
    });
    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Theo ngày'), findsOneWidget);
    expect(find.text('Thiết kế web nâng cao'), findsAtLeastNWidgets(1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('stale warning mirrors FAB, opens and closes across widths', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final old = DateTime.now().subtract(const Duration(days: 3));
    final snapshot = ImportedScheduleData(
      displayName: 'Sinh viên',
      records: const <ScheduleRecord>[],
      syncedAt: old,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_snapshot_v1': snapshot.encode(),
    });
    for (final width in <double>[360, 800]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      final warning = find.byTooltip('Đã lâu chưa đồng bộ');
      final options = find.ancestor(
        of: find.byIcon(Icons.grid_view_rounded),
        matching: find.byType(FloatingActionButton),
      );
      expect(warning, findsOneWidget);
      expect(options, findsOneWidget);
      final left = tester.getRect(warning);
      final right = tester.getRect(options);
      expect(left.size, right.size);
      expect(left.top, right.top);
      expect(left.left + right.right, closeTo(width, 1));
      await tester.tap(warning);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bạn đã lâu chưa đồng bộ dữ liệu rồi.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'recent sync hides warning; assistant selection survives restart',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final snapshot = ImportedScheduleData(
        displayName: 'Sinh viên',
        records: const <ScheduleRecord>[],
        syncedAt: DateTime.now().subtract(const Duration(hours: 47)),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'better_phenikaa_snapshot_v1': snapshot.encode(),
      });
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Đã lâu chưa đồng bộ'), findsNothing);
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài khoản').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Chọn Trợ lí'));
      await tester.tap(find.byTooltip('Chọn Trợ lí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Học thuật').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Trợ lí: Học thuật'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài khoản').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Trợ lí: Học thuật'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'notification center replaces bell Snackbar and opens exam page',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final now = DateTime.now();
      final snapshot = ImportedScheduleData(
        displayName: 'Sinh viên',
        records: <ScheduleRecord>[
          ScheduleRecord(
            id: 'exam',
            isExam: true,
            subjectName: 'Thiết kế web nâng cao',
            room: 'A1',
            startAt: now.add(const Duration(days: 2)),
            endAt: now.add(const Duration(days: 2, hours: 2)),
          ),
        ],
        syncedAt: now,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'better_phenikaa_snapshot_v1': snapshot.encode(),
      });
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đang trong kỳ thi'));
      await tester.pumpAndSettle();
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.byTooltip('Mở lịch thi'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byTooltip('Mở lịch thi'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch thi'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
