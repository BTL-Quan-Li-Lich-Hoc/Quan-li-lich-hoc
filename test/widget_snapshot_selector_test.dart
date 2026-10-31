import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_snapshot_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the current class before the next class', () {
    const selector = WidgetSnapshotSelector();
    final classes = <ClassDto>[
      _class('later', 10, 12),
      _class('current', 8, 10),
    ];

    final result = selector.selectForDate(
      classes: classes,
      selectedDate: DateTime(2026, 10, 31),
      now: DateTime(2026, 10, 31, 9),
    );

    expect(result?.subjectName, 'current');
  });

  test('returns null when the selected day has no classes', () {
    const selector = WidgetSnapshotSelector();
    final result = selector.selectForDate(
      classes: <ClassDto>[],
      selectedDate: DateTime(2026, 10, 31),
      now: DateTime(2026, 10, 31, 9),
    );
    expect(result, isNull);
  });
}

ClassDto _class(String name, int startHour, int endHour) {
  return ClassDto(
    id: name,
    subjectCode: name,
    subjectName: name,
    room: 'A101',
    lecturer: '',
    startAt: DateTime(2026, 10, 31, startHour),
    endAt: DateTime(2026, 10, 31, endHour),
  );
}
