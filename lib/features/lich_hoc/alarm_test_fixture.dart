import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';

/// UI-only fixtures for the side-by-side 1.6 APK.
/// Do not persist these to QLDT, sync snapshots, notifications or widgets.
ImportedScheduleData withAlarmTestFixture(
  ImportedScheduleData? original,
  DateTime now,
) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final minutesNow = now.hour * 60 + now.minute;

  // Each test class starts tomorrow at a clock time that has *already
  // passed today*. That makes ACTION_SET_ALARM schedule a one-off for tomorrow
  // without bypassing production eligibility and Android's native safeguards.
  // During the very first minute after midnight, an eligible class time
  // cannot exist; the first fixture becomes available at 00:01.
  int eligibleMinute(int minutesAgo) =>
      (minutesNow - minutesAgo).clamp(1, 1439).toInt();

  ScheduleRecord mock(String key, int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    final starts = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    return ScheduleRecord(
      id: 'bpa16-fixture-$key-${tomorrow.year}-${tomorrow.month}-${tomorrow.day}',
      subjectName: '[TEST 1.6] ${switch (key) {
        'ready-1' => 'Lập trình thiết bị di động',
        'ready-5' => 'Phân tích thiết kế hệ thống',
        _ => 'Cơ sở dữ liệu',
      }}',
      room: 'Lịch giả • không thuộc QLĐT',
      startAt: starts,
      endAt: starts.add(Duration(minutes: minuteOfDay + 45 > 1440
          ? 1440 - minuteOfDay
          : 45)),
      isExam: false,
    );
  }

  return ImportedScheduleData(
    displayName: original?.displayName.isNotEmpty == true
        ? original!.displayName
        : 'BPA 1.6 - Alarm Test',
    records: <ScheduleRecord>[
      ...?original?.records,
      mock('ready-1', eligibleMinute(1)),
      mock('ready-5', eligibleMinute(5)),
      mock('ready-15', eligibleMinute(15)),
    ]..sort((a, b) => a.startAt.compareTo(b.startAt)),
    syncedAt: original?.syncedAt ?? now,
    source: original?.source ?? 'alarm_test_ui_only',
  );
}
