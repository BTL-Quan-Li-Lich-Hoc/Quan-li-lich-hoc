import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/timetable/domain/schedule_queries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes prefix and whitespace', () {
    expect(
      ScheduleQueries.normalizeSubject('  Môn   Toán  cao cấp  '),
      'Toán cao cấp',
    );
  });
  test('week begins on Monday and is ordered', () {
    ClassDto item(String id, int day) => ClassDto(
      id: id,
      subjectCode: id,
      subjectName: id,
      room: 'A1',
      lecturer: '',
      startAt: DateTime(2026, 10, day, 7),
      endAt: DateTime(2026, 10, day, 9),
    );
    final result = ScheduleQueries.inWeek([
      item('fri', 23),
      item('mon', 19),
      item('next', 26),
    ], DateTime(2026, 10, 22));
    expect(result.map((e) => e.id).toList(), ['mon', 'fri']);
  });
}
