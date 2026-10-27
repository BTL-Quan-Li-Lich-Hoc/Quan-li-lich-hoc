import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cache round trips schedule and exam', () {
    final now = DateTime(2026, 10, 22);
    final payload = QldtImportPayload(user: const UserDto(studentId: 'demo', displayName: 'Test'), semester: SemesterDto(id: 's1', name: 'Học kỳ 1', startDate: now, endDate: now), classes: [ClassDto(id: '1', subjectCode: 'A', subjectName: 'Toán', room: 'A1', lecturer: '', startAt: now, endAt: now.add(const Duration(hours: 2)))], exams: const [], syncedAt: now);
    final result = LocalCacheCodec.decode(LocalCacheCodec.encode(payload));
    expect(result.classes.single.subjectName, 'Toán');
    expect(result.user.studentId, 'demo');
  });
}
