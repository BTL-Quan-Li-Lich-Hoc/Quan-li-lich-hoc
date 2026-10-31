import 'dart:convert';

import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_source.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(AppThemeController.instance.resetAfterLogout);
  tearDown(AppThemeController.instance.resetAfterLogout);

  ScheduleRecord exam(DateTime start, DateTime end) => ScheduleRecord(
    id: 'exam',
    isExam: true,
    subjectName: 'Môn thi',
    room: 'A1',
    startAt: start,
    endAt: end,
  );

  Future<void> showApp(
    WidgetTester tester,
    List<ScheduleRecord> records, {
    bool unreadDifference = false,
    SemesterDifference? difference,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final snapshot = ImportedScheduleData(
      displayName: 'Sinh viên',
      records: records,
      syncedAt: DateTime.now(),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_snapshot_v1': snapshot.encode(),
      if (difference != null)
        SemesterDifferenceStore.storageKey: jsonEncode(difference.toJson()),
      if (unreadDifference && difference == null)
        SemesterDifferenceStore.storageKey: jsonEncode(
          const SemesterDifference(
            initial: false,
            addedSubjects: <String>['Môn thi'],
            removedSubjects: <String>[],
            study: ScheduleDifference(added: 0, removed: 0, modified: 0),
            exams: ScheduleDifference(added: 1, removed: 0, modified: 0),
          ).toJson(),
        ),
    });
    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('empty or finished exams do not show the period badge', (
    tester,
  ) async {
    await showApp(tester, <ScheduleRecord>[]);
    expect(find.byKey(const ValueKey<String>('exam-period-dot')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await showApp(tester, <ScheduleRecord>[
      exam(yesterday.subtract(const Duration(hours: 2)), yesterday),
    ]);
    expect(find.byKey(const ValueKey<String>('exam-period-dot')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'period status survives notification center and exam navigation',
    (tester) async {
      final start = DateTime.now().add(const Duration(days: 2));
      await showApp(tester, <ScheduleRecord>[
        exam(start, start.add(const Duration(hours: 2))),
      ]);
      const dot = ValueKey<String>('exam-period-dot');
      expect(find.byKey(dot), findsOneWidget);
      await tester.tap(find.byTooltip('Đang trong kỳ thi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn đang trong kỳ thi. Nhớ kiểm tra lịch thi nhé.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Mở lịch thi'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.byTooltip('Mở lịch thi'));
      await tester.pumpAndSettle();
      expect(find.byKey(dot), findsOneWidget);
      expect(find.text('Còn 2 ngày'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await showApp(tester, <ScheduleRecord>[
        exam(start, start.add(const Duration(hours: 2))),
      ]);
      expect(find.byKey(dot), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('opening center preserves unread until details are opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await showApp(tester, <ScheduleRecord>[], unreadDifference: true);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Thay đổi môn học'), findsOneWidget);
    expect(find.text('Chi tiết'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('exam-period-dot')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Thay đổi lịch gần nhất'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('exam-period-dot')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  SemesterDifference changed({int study = 0, int exams = 0}) =>
      SemesterDifference(
        initial: false,
        addedSubjects: const <String>[],
        removedSubjects: const <String>[],
        study: ScheduleDifference(added: study, removed: 0, modified: 0),
        exams: ScheduleDifference(added: exams, removed: 0, modified: 0),
      );

  testWidgets('notification groups show only the changed schedule types', (
    tester,
  ) async {
    for (final item
        in <
          ({int study, int exams, List<String> expected, List<String> absent})
        >[
          (
            study: 1,
            exams: 0,
            expected: <String>['Thay đổi môn học'],
            absent: <String>['Thay đổi lịch thi'],
          ),
          (
            study: 0,
            exams: 1,
            expected: <String>['Thay đổi lịch thi'],
            absent: <String>['Thay đổi môn học'],
          ),
          (
            study: 1,
            exams: 1,
            expected: <String>['Thay đổi môn học', 'Thay đổi lịch thi'],
            absent: const <String>[],
          ),
        ]) {
      await showApp(
        tester,
        <ScheduleRecord>[],
        difference: changed(study: item.study, exams: item.exams),
      );
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      for (final title in item.expected) {
        expect(find.text(title), findsOneWidget);
      }
      for (final title in item.absent) {
        expect(find.text(title), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('notification center has a nonblank empty state', (tester) async {
    await showApp(tester, <ScheduleRecord>[]);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Không có thông báo mới.'), findsOneWidget);
    expect(find.text('Các thông báo mới sẽ xuất hiện ở đây.'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final theme in <AppThemeId>[
    AppThemeId.classic,
    AppThemeId.minecraft,
    AppThemeId.valorant,
  ]) {
    testWidgets('notification center fits $theme', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final start = DateTime.now().add(const Duration(days: 2));
      await showApp(tester, <ScheduleRecord>[
        exam(start, start.add(const Duration(hours: 2))),
      ], unreadDifference: true);
      final selection = AppThemeController.instance.select(theme);
      // Minecraft and Valorant keep animated backgrounds alive, so settling
      // every frame would wait forever even after the theme has applied.
      await tester.pump(const Duration(milliseconds: 700));
      await selection;
      await tester.tap(find.byTooltip('Đang trong kỳ thi'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.text('Bạn đang trong kỳ thi. Nhớ kiểm tra lịch thi nhé.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'custom notification theme and font keep arrow card within screen',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final custom = CustomThemeDefinition(
        id: 'notification-test',
        name: 'Notification',
        source: const ThemeSourceData.colorMix(
          colors: <Color>[Color(0xFF7755AA), Color(0xFF334477)],
          weights: <double>[60, 40],
        ),
        tokens: appThemePalettes[AppThemeId.valorant]!.toTokens(),
        font: AppFontChoice.builtIns[1],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final start = DateTime.now().add(const Duration(days: 2));
      await showApp(tester, <ScheduleRecord>[
        exam(start, start.add(const Duration(hours: 2))),
      ]);
      final selection = AppThemeController.instance.applyCustomTheme(custom);
      await tester.pump(const Duration(milliseconds: 650));
      await selection;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đang trong kỳ thi'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byTooltip('Mở lịch thi')).width,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final theme in <AppThemeId>[
    AppThemeId.classic,
    AppThemeId.minecraft,
    AppThemeId.valorant,
  ]) {
    testWidgets('countdown fits and remains readable in $theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final start = DateTime.now().add(const Duration(days: 10));
      await showApp(tester, <ScheduleRecord>[
        exam(start, start.add(const Duration(hours: 2))),
      ]);
      final selection = AppThemeController.instance.select(theme);
      await tester.pump(const Duration(milliseconds: 650));
      await selection;
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch thi').last);
      await tester.pumpAndSettle();
      expect(find.text('Còn 10 ngày'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('custom palette and wide custom font keep the tag within card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final start = DateTime.now().add(const Duration(days: 5));
    await showApp(tester, <ScheduleRecord>[
      exam(start, start.add(const Duration(hours: 2))),
    ]);
    final custom = CustomThemeDefinition(
      id: 'exam-test',
      name: 'Custom',
      source: const ThemeSourceData.colorMix(
        colors: <Color>[Color(0xFF101820), Color(0xFF184878)],
        weights: <double>[60, 40],
      ),
      tokens: appThemePalettes[AppThemeId.valorant]!.toTokens(),
      font: AppFontChoice.builtIns[1],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final selection = AppThemeController.instance.applyCustomTheme(custom);
    await tester.pump(const Duration(milliseconds: 650));
    await selection;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch thi').last);
    await tester.pumpAndSettle();
    expect(find.text('Còn 5 ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
