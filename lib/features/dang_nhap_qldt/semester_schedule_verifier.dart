import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class VerifiedSemesterSchedules {
  const new({required this.studySchedules, required this.examSchedules});

  final List<ScheduleRecord> studySchedules;
  final List<ScheduleRecord> examSchedules;
}

final class SemesterScheduleVerifier {
  const new();

  VerifiedSemesterSchedules verify({
    required RegisteredSemester registration,
    required ImportedScheduleData schedule,
  }) {
    final classes = <String, Map<String, RegisteredClassSection>>{};
    for (final name in registration.subjectNames) {
      final normalized = normalizeSubjectName(name);
      final sections =
          registration.classSections[name] ?? const <RegisteredClassSection>[];
      if (classes.containsKey(normalized)) {
        throw FormatException('Trùng môn đăng ký: $name');
      }
      final sectionNames = sections
          .map((section) => normalizeClassName(section.name))
          .toList();
      if (sectionNames.toSet().length != sectionNames.length ||
          sectionNames.any((value) => value.isEmpty)) {
        throw FormatException('TraCuu có lớp trùng hoặc thiếu tên: $name');
      }
      classes[normalized] = {
        for (final section in sections)
          normalizeClassName(section.name): section,
      };
    }
    if (classes.isEmpty &&
        (!registration.confirmedEmpty || schedule.records.isNotEmpty)) {
      throw const FormatException(
        'Chưa xác minh được môn của học kỳ mới nhất.',
      );
    }

    final study = <ScheduleRecord>[];
    final exams = <ScheduleRecord>[];
    for (final row in schedule.records) {
      final subject = classes[normalizeSubjectName(row.subjectName)];
      if (subject == null) continue;
      final className = normalizeClassName(row.className);
      if (row.isExam) {
        // QLĐT sometimes puts the exam format (e.g. "Trắc nghiệm trên máy
        // 30p") in TENLOPHOCPHAN instead of a registered class name.
        // Only accept a recognizable format when the subject and semester
        // have already been verified; a different class code is still wrong.
        final examLabel = normalizeClassName(row.examForm);
        const examFormats = <String>[
          'trắc nghiệm',
          'tự luận',
          'vấn đáp',
          'bài thi',
          'thi ',
          'trên máy',
          'thực hành',
          'online',
        ];
        final isExamFormat =
            className.isNotEmpty &&
            (className == examLabel && examLabel.isNotEmpty ||
                examFormats.any(
                  (label) => className.contains(normalizeClassName(label)),
                ));
        if (!subject.containsKey(className) && !isExamFormat) {
          throw FormatException(
            'Không xác minh được lớp của lịch: ${row.subjectName}',
          );
        }
        final earliestStart = subject.values
            .map((section) => section.startsOn)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        if (row.startAt.isBefore(earliestStart)) {
          throw FormatException(
            'Ca thi đứng trước học kỳ đăng ký: ${row.subjectName}',
          );
        }
        exams.add(row);
        continue;
      }
      if (className.isEmpty || !subject.containsKey(className)) {
        throw FormatException(
          'Không xác minh được lớp của lịch: ${row.subjectName}',
        );
      }
      final section = subject[className]!;
      final date = DateTime(
        row.startAt.year,
        row.startAt.month,
        row.startAt.day,
      );
      // TraCuu's class date range can lag the actual personal timetable by
      // a week. Class identity remains exact; tolerate only a small boundary
      // discrepancy, never a record from a distant term.
      if (date.isBefore(section.startsOn.subtract(const Duration(days: 14))) ||
          date.isAfter(section.endsOn.add(const Duration(days: 14)))) {
        throw FormatException(
          'Buổi học ngoài khoảng ngày lớp: ${row.subjectName}',
        );
      }
      study.add(row);
    }
    return VerifiedSemesterSchedules(
      studySchedules: study,
      examSchedules: exams,
    );
  }
}
