import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts empty until repositories are connected', () async {
    final coordinator = ScheduleCoordinator(
      initialDay: DateTime(2026, 10, 26),
    );

    await coordinator.load();

    expect(coordinator.status, ScheduleLoadStatus.empty);
    expect(coordinator.classes, isEmpty);
    expect(coordinator.exams, isEmpty);
  });

  test('normalizes the selected date before reloading', () async {
    final coordinator = ScheduleCoordinator(
      initialDay: DateTime(2026, 10, 26),
    );

    await coordinator.chooseDay(DateTime(2026, 10, 27, 19, 45));

    expect(coordinator.selectedDay, DateTime(2026, 10, 27));
  });

  test('accepts a payload that uses the shared contracts', () {
    final coordinator = ScheduleCoordinator();
    final classItem = ClassDto(
      id: 'class-1',
      subjectCode: 'MOB101',
      subjectName: 'Lập trình di động',
      room: 'A101',
      lecturer: 'Nguyễn Văn A',
      startAt: DateTime(2026, 10, 26, 8),
      endAt: DateTime(2026, 10, 26, 10),
    );
    final examItem = ExamDto(
      id: 'exam-1',
      subjectCode: 'MOB101',
      subjectName: 'Lập trình di động',
      room: 'B202',
      startAt: DateTime(2026, 11, 2, 13),
      endAt: DateTime(2026, 11, 2, 15),
    );
    final payload = QldtImportPayload(
      user: const UserDto(studentId: 'test', displayName: 'Sinh viên thử nghiệm'),
      semester: SemesterDto(
        id: '2026-1',
        name: 'Học kỳ 1',
        startDate: DateTime(2026, 8),
        endDate: DateTime(2027, 1),
      ),
      classes: <ClassDto>[classItem],
      exams: <ExamDto>[examItem],
      syncedAt: DateTime(2026, 10, 26),
    );

    coordinator.showPayload(payload);

    expect(coordinator.status, ScheduleLoadStatus.ready);
    expect(coordinator.classes, <ClassDto>[classItem]);
    expect(coordinator.exams, <ExamDto>[examItem]);
  });
}
