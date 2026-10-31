import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_schedule_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists schedule and exam data for offline reads', () async {
    final store = await LocalScheduleStore.open();
    final start = DateTime(2026, 10, 31, 8);
    final payload = QldtImportPayload(
      user: const UserDto(studentId: 'test', displayName: 'Sinh viên thử'),
      semester: SemesterDto(
        id: '2026-1',
        name: 'Học kỳ 1',
        startDate: DateTime(2026, 8),
        endDate: DateTime(2027, 1),
      ),
      classes: <ClassDto>[
        ClassDto(
          id: 'class-1',
          subjectCode: 'MOB101',
          subjectName: 'Lập trình di động',
          room: 'A101',
          lecturer: 'Giảng viên',
          startAt: start,
          endAt: start.add(const Duration(hours: 2)),
        ),
      ],
      exams: <ExamDto>[
        ExamDto(
          id: 'exam-1',
          subjectCode: 'MOB101',
          subjectName: 'Lập trình di động',
          room: 'B202',
          startAt: DateTime(2026, 11, 20, 13),
          endAt: DateTime(2026, 11, 20, 15),
        ),
      ],
      syncedAt: DateTime(2026, 10, 31),
    );

    await store.replaceImport(payload);
    final classes = await store
        .watchRange(from: DateTime(2026, 10, 31), to: DateTime(2026, 11, 1))
        .first;
    final exams = await store.watchAll().first;

    expect(classes.single.subjectName, 'Lập trình di động');
    expect(exams.single.room, 'B202');
    await store.dispose();
  });

  test('stores a widget snapshot locally', () async {
    final store = await LocalScheduleStore.open();
    final start = DateTime(2026, 10, 31, 8);
    final snapshot = WidgetSnapshot(
      subjectName: 'Lập trình di động',
      room: 'A101',
      startAt: start,
      endAt: start.add(const Duration(hours: 2)),
    );

    await store.write(snapshot);
    final restored = await store.read();

    expect(restored?.subjectName, snapshot.subjectName);
    expect(restored?.room, snapshot.room);
    expect(restored?.startAt, snapshot.startAt);
    await store.dispose();
  });
}
