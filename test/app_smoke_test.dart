import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('app boots to the bootstrap screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BetterPhenikaaScheduleApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Better Phenikaa Schedule'), findsOneWidget);
  });
  test('lưu và đọc lại lịch offline', () async {
    const cache = QldtLocalCache();
    final item = ClassDto(
      id: 'lop-1',
      subjectCode: 'WEB101',
      subjectName: 'Thiết kế web nâng cao',
      room: 'A101',
      lecturer: 'Giảng viên',
      startAt: DateTime(2026, 11, 2, 7),
      endAt: DateTime(2026, 11, 2, 9),
    );
    final payload = QldtImportPayload(
      user: const UserDto(studentId: '24100041', displayName: 'Sinh viên'),
      semester: SemesterDto(
        id: '2026-1',
        name: 'Học kỳ 1',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2026, 12),
      ),
      classes: <ClassDto>[item],
      exams: const <ExamDto>[],
      syncedAt: DateTime(2026, 11, 1),
    );

    await cache.save(payload);
    final restored = await cache.read();
    expect(restored?.user.studentId, '24100041');
    expect(restored?.classes.single.subjectName, 'Thiết kế web nâng cao');
    expect(restored?.semester.id, '2026-1');
    await cache.clear();
    expect(await cache.read(), isNull);
  });

  test('dữ liệu sai không ghi đè lịch cũ', () async {
    const cache = QldtLocalCache();
    final valid = QldtImportPayload(
      user: const UserDto(studentId: 'sv-1', displayName: 'Sinh viên'),
      semester: SemesterDto(
        id: 'ky-1',
        name: 'Học kỳ 1',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2026, 12),
      ),
      classes: const <ClassDto>[],
      exams: const <ExamDto>[],
      syncedAt: DateTime(2026, 11),
    );
    await cache.save(valid);
    final invalid = QldtImportPayload(
      user: const UserDto(studentId: '', displayName: ''),
      semester: valid.semester,
      classes: valid.classes,
      exams: valid.exams,
      syncedAt: valid.syncedAt,
    );
    await expectLater(cache.save(invalid), throwsFormatException);
    expect((await cache.read())?.user.studentId, 'sv-1');
  });
}
