import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_retention.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps an older semester through its last retention day', () {
    final old = CurrentSemester(
      semesterId: '2026_2027_1',
      semesterName: '2026_2027_1',
      displayName: '',
      syncedAt: DateTime(2026, 9, 26),
      subjects: const <SemesterSubject>[],
    );
    final retained = RetainedSemester(old, DateTime(2026, 8, 17));
    expect(retained.expiresOn, DateTime(2026, 12, 24));
    expect(retained.activeAt(DateTime(2026, 12, 24, 23, 59)), isTrue);
    expect(retained.activeAt(DateTime(2026, 12, 25)), isFalse);
    expect(
      RetainedSemester.decode(retained.encode()).semester.semesterId,
      '2026_2027_1',
    );
  });
}
