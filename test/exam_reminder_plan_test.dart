import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/exam_reminder_plan.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ExamReminderPlanner();

  CurrentSemester semester({DateTime? examAt, String room = 'C3'}) {
    final at = examAt ?? DateTime(2026, 12, 10, 8);
    return const SemesterDataBuilder().build(
      registration: const RegisteredSemester(
        id: '2026_2027_1',
        name: '2026_2027_1',
        subjectNames: <String>['Thiết kế web nâng cao'],
      ),
      studySchedules: const <ScheduleRecord>[],
      examSchedules: <ScheduleRecord>[
        ScheduleRecord(
          id: 'exam',
          isExam: true,
          subjectName: 'Thiết kế web nâng cao',
          room: room,
          startAt: at,
          endAt: at.add(const Duration(hours: 2)),
        ),
      ],
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 11, 1),
    );
  }

  test('plans 7, 3 and 1 day milestones only once', () {
    final current = semester();
    final first = planner.plan(
      semester: current,
      now: DateTime(2026, 12, 1),
      scheduledKeys: <String>{},
      deliveredKeys: <String>{},
    );
    expect(first.schedule.map((item) => item.daysBefore), <int>[7, 3, 1]);
    final scheduled = first.schedule.map((item) => item.key).toSet();
    final second = planner.plan(
      semester: current,
      now: DateTime(2026, 12, 1),
      scheduledKeys: scheduled,
      deliveredKeys: <String>{},
    );
    expect(second.schedule, isEmpty);
    expect(second.cancelKeys, isEmpty);
    final afterFirstMilestone = planner.plan(
      semester: current,
      now: DateTime(2026, 12, 4),
      scheduledKeys: scheduled,
      deliveredKeys: <String>{first.schedule.first.key},
    );
    expect(afterFirstMilestone.schedule, isEmpty);
    expect(afterFirstMilestone.cancelKeys, <String>{first.schedule.first.key});
  });

  test('cancelled or moved exam invalidates old reminder keys', () {
    final old = semester();
    final oldKeys = planner
        .plan(
          semester: old,
          now: DateTime(2026, 12, 1),
          scheduledKeys: <String>{},
          deliveredKeys: <String>{},
        )
        .schedule
        .map((item) => item.key)
        .toSet();
    final moved = planner.plan(
      semester: semester(examAt: DateTime(2026, 12, 15, 9)),
      now: DateTime(2026, 12, 1),
      scheduledKeys: oldKeys,
      deliveredKeys: <String>{},
    );
    expect(moved.cancelKeys, oldKeys);
    expect(moved.schedule, hasLength(3));
    final removed = const SemesterDataBuilder().build(
      registration: const RegisteredSemester(
        id: '2026_2027_1',
        name: '2026_2027_1',
        subjectNames: <String>['Thiết kế web nâng cao'],
      ),
      studySchedules: const <ScheduleRecord>[],
      examSchedules: const <ScheduleRecord>[],
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 12, 1),
    );
    expect(
      planner
          .plan(
            semester: removed,
            now: DateTime(2026, 12, 1),
            scheduledKeys: oldKeys,
            deliveredKeys: <String>{},
          )
          .cancelKeys,
      oldKeys,
    );
  });
}
