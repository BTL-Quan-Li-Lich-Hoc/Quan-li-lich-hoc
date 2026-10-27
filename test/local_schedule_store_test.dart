import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_schedule_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('persists the whole validated import offline', () async {
    final store = await LocalScheduleStore.open();
    final now = DateTime(2026, 10, 22);
    final payload = QldtImportPayload(user: const UserDto(studentId: 'demo', displayName: 'Student'), semester: SemesterDto(id: 's', name: 'S', startDate: now, endDate: now), classes: [ClassDto(id: 'c', subjectCode: 'm', subjectName: 'Lịch học', room: 'A1', lecturer: '', startAt: now, endAt: now.add(const Duration(hours: 2)))], exams: const [], syncedAt: now);
    await store.replaceImport(payload);
    final another = await LocalScheduleStore.open();
    expect(another.current!.classes.single.subjectName, 'Lịch học');
    await store.dispose();
    await another.dispose();
  });
}
