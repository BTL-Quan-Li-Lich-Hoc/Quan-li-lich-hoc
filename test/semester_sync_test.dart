import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = CurrentSemesterStore();
  final coordinator = SemesterSyncCoordinator(store: store);

  CurrentSemester build(String room) => const SemesterDataBuilder().build(
    registration: const RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: <String>['Thiết kế web nâng cao'],
    ),
    studySchedules: <ScheduleRecord>[
      ScheduleRecord(
        id: 'one',
        isExam: false,
        subjectName: 'Thiết kế web nâng cao',
        room: room,
        startAt: DateTime(2026, 9, 23, 7),
        endAt: DateTime(2026, 9, 23, 9),
      ),
    ],
    examSchedules: const <ScheduleRecord>[],
    displayName: 'Sinh viên',
    syncedAt: DateTime(2026, 9, 23),
  );

  test('first and repeated successful sync update the baseline', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final initial = await coordinator.sync(() async => build('A1'));
    expect(initial.initial, isTrue);
    expect(initial.hasChanges, isFalse);
    expect(
      (await store.read())!.subjects.single.studySchedules.single.room,
      'A1',
    );
    final unchanged = await coordinator.sync(() async => build('A1'));
    expect(unchanged.initial, isFalse);
    expect(unchanged.hasChanges, isFalse);
    final changed = await coordinator.sync(() async => build('B2'));
    expect(changed.study.modified, 1);
    expect(
      (await store.read())!.subjects.single.studySchedules.single.room,
      'B2',
    );
  });

  test(
    'network and validation failures preserve the last complete semester',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await coordinator.sync(() async => build('A1'));
      await expectLater(
        coordinator.sync(() async => throw const FormatException('Mất mạng')),
        throwsFormatException,
      );
      await expectLater(
        coordinator.sync(
          () async => throw const FormatException(
            'Không xác định được một kế hoạch đăng ký.',
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        coordinator.sync(
          () async => const SemesterDataBuilder().build(
            registration: const RegisteredSemester(
              id: '2026_2027_1',
              name: '2026_2027_1',
              subjectNames: <String>[],
            ),
            studySchedules: const <ScheduleRecord>[],
            examSchedules: const <ScheduleRecord>[],
            displayName: 'Sinh viên',
            syncedAt: DateTime(2026, 9, 23),
          ),
        ),
        throwsFormatException,
      );
      final restored = await store.read();
      expect(restored!.subjects.single.studySchedules.single.room, 'A1');
    },
  );

  test('a confirmed empty registration remains a valid first sync', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final difference = await coordinator.sync(
      () async => const SemesterDataBuilder().build(
        registration: const RegisteredSemester(
          id: '2026_2027_1',
          name: '2026_2027_1',
          subjectNames: <String>[],
          confirmedEmpty: true,
        ),
        studySchedules: const <ScheduleRecord>[],
        examSchedules: const <ScheduleRecord>[],
        displayName: 'Sinh viên',
        syncedAt: DateTime(2026, 9, 23),
      ),
    );
    expect(difference.initial, isTrue);
    expect((await store.read())!.subjects, isEmpty);
  });
}
