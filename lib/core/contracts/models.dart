final class UserDto {
  const new({required this.studentId, required this.displayName});

  final String studentId;
  final String displayName;
}

final class SemesterDto {
  const new({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
}

final class ClassDto {
  const new({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.room,
    required this.lecturer,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final String room;
  final String lecturer;
  final DateTime startAt;
  final DateTime endAt;
}

final class ExamDto {
  const new({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.room,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final String room;
  final DateTime startAt;
  final DateTime endAt;
}

final class QldtImportPayload {
  const new({
    required this.user,
    required this.semester,
    required this.classes,
    required this.exams,
    required this.syncedAt,
  });

  final UserDto user;
  final SemesterDto semester;
  final List<ClassDto> classes;
  final List<ExamDto> exams;
  final DateTime syncedAt;
}

final class WidgetSnapshot {
  const new({
    required this.subjectName,
    required this.room,
    required this.startAt,
    required this.endAt,
  });

  final String subjectName;
  final String room;
  final DateTime startAt;
  final DateTime endAt;
}
