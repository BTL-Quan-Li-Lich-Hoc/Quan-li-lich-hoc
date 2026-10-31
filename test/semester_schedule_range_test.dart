import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a personal term expires four calendar months and seven days later', () {
    final registration = RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: const <String>['Môn A', 'Môn B'],
      classSections: <String, List<RegisteredClassSection>>{
        'Môn A': <RegisteredClassSection>[
          RegisteredClassSection(
            name: 'A1',
            startsOn: DateTime(2026, 8, 17),
            endsOn: DateTime(2026, 11, 1),
          ),
        ],
        'Môn B': <RegisteredClassSection>[
          RegisteredClassSection(
            name: 'B1',
            startsOn: DateTime(2026, 9, 1),
            endsOn: DateTime(2026, 12, 1),
          ),
        ],
      },
    );
    final range = SemesterScheduleRange.fromRegistration(registration)!;
    expect(range.start, DateTime(2026, 8, 17));
    expect(range.end, DateTime(2026, 12, 24));
  });

  test('an empty registration cannot provide safe semester bounds', () {
    const registration = RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: <String>[],
      confirmedEmpty: true,
    );
    expect(SemesterScheduleRange.fromRegistration(registration), isNull);
  });

  test('the month is clamped before adding seven days', () {
    expect(semesterExpiry(DateTime(2026, 10, 31)), DateTime(2027, 3, 7));
  });
}
