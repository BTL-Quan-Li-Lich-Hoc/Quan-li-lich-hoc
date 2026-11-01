import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/scroll_day_timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Lịch học và lịch thi được tách đúng', () {
    final date = DateTime(2026, 11, 2);
    final lesson = ScheduleRecord(
      id: 'class-1',
      isExam: false,
      subjectName: 'Lập trình di động',
      room: 'A101',
      startAt: date.add(const Duration(hours: 7)),
      endAt: date.add(const Duration(hours: 9)),
    );
    final exam = ScheduleRecord(
      id: 'exam-1',
      isExam: true,
      subjectName: 'Kiểm thử phần mềm',
      room: 'B202',
      startAt: date.add(const Duration(hours: 13)),
      endAt: date.add(const Duration(hours: 15)),
    );
    final schedule = ImportedScheduleData(
      displayName: 'Sinh viên thử nghiệm',
      records: <ScheduleRecord>[lesson, exam],
      syncedAt: date,
    );

    expect(schedule.classes.single.id, 'class-1');
    expect(schedule.exams.single.id, 'exam-1');

    final decoded = ImportedScheduleData.decode(schedule.encode());
    expect(decoded.records.length, 2);
    expect(decoded.displayName, schedule.displayName);
    expect(decoded.classes.single.subjectName, lesson.subjectName);
    expect(decoded.exams.single.room, exam.room);
  });

  test('Phản hồi QLĐT thất bại được từ chối', () {
    expect(
      () => const QldtParser().parseApiResponse(
        <String, dynamic>{'Success': false, 'Data': <Object>[]},
        displayName: '',
      ),
      throwsFormatException,
    );
  });

  test('Chỉ có một chế độ Scroll bên cạnh Ngày/Tuần', () {
    expect(ScheduleDisplayMode.values,
        <ScheduleDisplayMode>[ScheduleDisplayMode.standard, ScheduleDisplayMode.scroll]);
  });
}
