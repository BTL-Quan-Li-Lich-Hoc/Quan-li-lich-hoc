import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const detector = SemesterChangeDetector();
  const builder = SemesterDataBuilder();

  ScheduleRecord row({
    required String subject,
    bool exam = false,
    String room = 'A1',
    String className = 'C-2026',
    int day = 23,
    int hour = 7,
  }) => ScheduleRecord(
    id: '$subject|$day|$hour|$room',
    isExam: exam,
    subjectName: subject,
    room: room,
    className: className,
    startAt: DateTime(2026, 9, day, hour),
    endAt: DateTime(2026, 9, day, hour + 2),
  );

  CurrentSemester state({
    List<String> names = const <String>['Thiết kế web nâng cao'],
    List<ScheduleRecord> study = const <ScheduleRecord>[],
    List<ScheduleRecord> exams = const <ScheduleRecord>[],
  }) => builder.build(
    registration: RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: names,
    ),
    studySchedules: study,
    examSchedules: exams,
    displayName: 'Sinh viên',
    syncedAt: DateTime(2026, 9, 23),
  );

  test(
    'first sync establishes baseline; next identical sync has no changes',
    () {
      final current = state(
        study: <ScheduleRecord>[row(subject: 'Thiết kế web nâng cao')],
      );
      expect(detector.compare(null, current).initial, isTrue);
      expect(detector.compare(null, current).hasChanges, isFalse);
      final identical = state(
        study: <ScheduleRecord>[
          row(subject: ' THIẾT KẾ  WEB NÂNG CAO ', room: ' A1 '),
        ],
      );
      expect(detector.compare(current, identical).hasChanges, isFalse);
    },
  );

  test('detects added and cancelled subjects and schedules', () {
    final before = state(
      study: <ScheduleRecord>[row(subject: 'Thiết kế web nâng cao')],
    );
    final after = state(
      names: const <String>['Toán cao cấp'],
      study: <ScheduleRecord>[row(subject: 'Toán cao cấp')],
    );
    final change = detector.compare(before, after);
    expect(change.addedSubjects, <String>['Toán cao cấp']);
    expect(change.removedSubjects, <String>['Thiết kế web nâng cao']);
    expect(change.study.added, 1);
    expect(change.study.removed, 1);
  });

  test(
    'detects room, class, day and time changes without replacing subject',
    () {
      final before = state(
        study: <ScheduleRecord>[row(subject: 'Thiết kế web nâng cao')],
      );
      for (final changed in <ScheduleRecord>[
        row(subject: 'Thiết kế web nâng cao', room: 'B2'),
        row(subject: 'Thiết kế web nâng cao', className: 'C-2026-NEW'),
        row(subject: 'Thiết kế web nâng cao', day: 24),
        row(subject: 'Thiết kế web nâng cao', hour: 9),
      ]) {
        final diff = detector.compare(
          before,
          state(study: <ScheduleRecord>[changed]),
        );
        expect(diff.addedSubjects, isEmpty);
        expect(diff.removedSubjects, isEmpty);
        expect(diff.study.modified, 1);
        expect(diff.study.details.single.kind, 'modified');
        expect(diff.study.details.single.before!.room, 'A1');
        expect(diff.study.details.single.after!.room, changed.room);
      }
    },
  );

  test('exam addition, cancellation, and change use the full stored set', () {
    final before = state(
      exams: <ScheduleRecord>[
        row(subject: 'Thiết kế web nâng cao', exam: true),
      ],
    );
    expect(detector.compare(state(), before).exams.added, 1);
    expect(detector.compare(before, state()).exams.removed, 1);
    final moved = state(
      exams: <ScheduleRecord>[
        row(subject: 'Thiết kế web nâng cao', exam: true, day: 24),
      ],
    );
    expect(detector.compare(before, moved).exams.modified, 1);
    expect(
      detector.compare(before, moved).exams.details.single.after!.startAt.day,
      24,
    );
    expect(detector.compare(before, before).hasChanges, isFalse);
  });

  test(
    'last successful difference survives reload and empty change replaces it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SemesterDifferenceStore();
      final previous = state();
      final next = state(
        study: <ScheduleRecord>[row(subject: 'Thiết kế web nâng cao')],
      );
      await store.save(detector.compare(previous, next));
      expect((await store.read())!.study.added, 1);
      expect(
        (await store.read())!.study.details.single.after!.subjectName,
        'Thiết kế web nâng cao',
      );
      await store.save(detector.compare(next, next));
      expect((await store.read())!.hasChanges, isFalse);
    },
  );
}
