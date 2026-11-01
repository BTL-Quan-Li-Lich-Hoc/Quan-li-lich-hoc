import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

String subjectDisplayName(String name) => name
    .trim()
    .replaceFirst(RegExp(r'^Môn\s+', caseSensitive: false), '')
    .replaceFirst(RegExp(r'-\d+-\d+-\d+\([^)]*\)(?:\.[\w]+)?$'), '')
    .trim();

String normalizeSubjectName(String name) =>
    _normalizeText(subjectDisplayName(name));

String normalizeClassName(String name) => _normalizeText(
  name.split(RegExp(r'<br\s*/?>', caseSensitive: false)).first,
);

String _normalizeText(String name) {
  final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final decomposed = StringBuffer();
  for (final rune in collapsed.runes) {
    final character = String.fromCharCode(rune);
    decomposed.write(_vietnameseDecomposition[character] ?? character);
  }
  final canonical = StringBuffer();
  final marks = <String>[];
  void flushMarks() {
    marks.sort((a, b) => _markOrder(a).compareTo(_markOrder(b)));
    canonical.writeAll(marks);
    marks.clear();
  }

  for (final rune in decomposed.toString().runes) {
    final character = String.fromCharCode(rune);
    if (_markOrder(character) < 1000) {
      marks.add(character);
    } else {
      flushMarks();
      canonical.write(character);
    }
  }
  flushMarks();
  return canonical.toString();
}

int _markOrder(String mark) => switch (mark) {
  '\u031b' => 216,
  '\u0323' => 220,
  '\u0300' || '\u0301' || '\u0302' || '\u0303' || '\u0306' || '\u0309' => 230,
  _ => 1000,
};

final class RegisteredSemester {
  const new({
    required this.id,
    required this.name,
    required this.subjectNames,
    this.classSections = const <String, List<RegisteredClassSection>>{},
    this.confirmedEmpty = false,
  });

  final String id;
  final String name;
  final List<String> subjectNames;
  final Map<String, List<RegisteredClassSection>> classSections;
  final bool confirmedEmpty;
}

final class RegisteredClassSection {
  const new({required this.name, required this.startsOn, required this.endsOn});

  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
}

final class SemesterSubject {
  const new({
    required this.subjectId,
    required this.name,
    required this.normalizedName,
    required this.studySchedules,
    required this.examSchedules,
  });

  factory fromJson(Map<String, dynamic> json) => SemesterSubject(
    subjectId: json['subjectId'] as String,
    name: json['name'] as String,
    normalizedName: json['normalizedName'] as String,
    studySchedules: _readRecords(json['studySchedules']),
    examSchedules: _readRecords(json['examSchedules']),
  );

  final String subjectId;
  final String name;
  final String normalizedName;
  final List<ScheduleRecord> studySchedules;
  final List<ScheduleRecord> examSchedules;

  Map<String, Object?> toJson() => <String, Object?>{
    'subjectId': subjectId,
    'name': name,
    'normalizedName': normalizedName,
    'studySchedules': studySchedules.map((item) => item.toJson()).toList(),
    'examSchedules': examSchedules.map((item) => item.toJson()).toList(),
  };
}

final class CurrentSemester {
  const new({
    required this.semesterId,
    required this.semesterName,
    required this.displayName,
    required this.syncedAt,
    required this.subjects,
  });

  factory fromJson(Map<String, dynamic> json) => CurrentSemester(
    semesterId: json['semesterId'] as String,
    semesterName: json['semesterName'] as String,
    displayName: json['displayName'] as String,
    syncedAt: DateTime.parse(json['syncedAt'] as String),
    subjects: (json['subjects'] as List<dynamic>)
        .map(
          (item) => SemesterSubject.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: false),
  );

  final String semesterId;
  final String semesterName;
  final String displayName;
  final DateTime syncedAt;
  final List<SemesterSubject> subjects;

  Map<String, Object?> toJson() => <String, Object?>{
    'semesterId': semesterId,
    'semesterName': semesterName,
    'displayName': displayName,
    'syncedAt': syncedAt.toIso8601String(),
    'subjects': subjects.map((item) => item.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  ImportedScheduleData toImportedScheduleData() {
    final records = <ScheduleRecord>[];
    for (final subject in subjects) {
      for (final schedule in <ScheduleRecord>[
        ...subject.studySchedules,
        ...subject.examSchedules,
      ]) {
        records.add(
          ScheduleRecord(
            id: '${subject.subjectId}|${schedule.id}',
            isExam: schedule.isExam,
            subjectName: subject.name,
            room: schedule.room,
            startAt: schedule.startAt,
            endAt: schedule.endAt,
            className: schedule.className,
            examForm: schedule.examForm,
            periodStart: schedule.periodStart,
            periodEnd: schedule.periodEnd,
          ),
        );
      }
    }
    records.sort((a, b) => a.startAt.compareTo(b.startAt));
    return ImportedScheduleData(
      displayName: displayName,
      records: records,
      syncedAt: syncedAt,
    );
  }
}

final class SemesterDataBuilder {
  const new();

  CurrentSemester build({
    required RegisteredSemester registration,
    required List<ScheduleRecord> studySchedules,
    required List<ScheduleRecord> examSchedules,
    required String displayName,
    required DateTime syncedAt,
  }) {
    if (registration.id.trim().isEmpty || registration.name.trim().isEmpty) {
      throw const FormatException('Không xác định được học kỳ mới nhất.');
    }

    final names = <String, String>{};
    for (final name in registration.subjectNames) {
      final normalized = normalizeSubjectName(name);
      if (normalized.isEmpty) {
        throw const FormatException('Danh sách đăng ký có tên môn trống.');
      }
      if (names.containsKey(normalized)) {
        throw FormatException('TraCuu trả nhiều môn cùng tên: $name');
      }
      names[normalized] = subjectDisplayName(name);
    }

    if (names.isEmpty && !registration.confirmedEmpty) {
      throw const FormatException('Không xác minh được danh sách môn đăng ký.');
    }

    List<ScheduleRecord> matching(
      String normalized,
      List<ScheduleRecord> rows, {
      required bool isExam,
    }) {
      return rows
          .where(
            (row) =>
                row.isExam == isExam &&
                normalizeSubjectName(row.subjectName) == normalized,
          )
          .toList();
    }

    for (final record in studySchedules) {
      if (record.isExam ||
          !names.containsKey(normalizeSubjectName(record.subjectName))) {
        throw FormatException(
          'Lịch học không khớp môn đăng ký: ${record.subjectName}',
        );
      }
    }
    for (final record in examSchedules) {
      if (!record.isExam ||
          !names.containsKey(normalizeSubjectName(record.subjectName))) {
        throw FormatException(
          'Lịch thi không khớp môn đăng ký: ${record.subjectName}',
        );
      }
    }

    final subjects = <SemesterSubject>[];
    for (final entry in names.entries) {
      final identity =
          '${registration.id.length}:${registration.id}${entry.key}';
      subjects.add(
        SemesterSubject(
          subjectId:
              'S${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}',
          name: entry.value,
          normalizedName: entry.key,
          studySchedules: matching(entry.key, studySchedules, isExam: false),
          examSchedules: matching(entry.key, examSchedules, isExam: true),
        ),
      );
    }
    return CurrentSemester(
      semesterId: registration.id,
      semesterName: registration.name,
      displayName: displayName,
      syncedAt: syncedAt,
      subjects: subjects,
    );
  }
}

final class CurrentSemesterStore {
  static const storageKey = 'better_phenikaa_current_semester_v1';

  Future<CurrentSemester?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    return raw == null
        ? null
        : CurrentSemester.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
          );
  }

  Future<void> save(CurrentSemester semester) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(storageKey, semester.encode())) {
      throw StateError('Không thể lưu dữ liệu học kỳ trên thiết bị.');
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(storageKey)) {
      throw StateError('Không thể xóa dữ liệu học kỳ trên thiết bị.');
    }
  }
}

List<ScheduleRecord> _readRecords(Object? raw) => (raw! as List<dynamic>)
    .map(
      (item) => ScheduleRecord.fromJson(
        Map<String, Object?>.from(item as Map<dynamic, dynamic>),
      ),
    )
    .toList(growable: false);

const _vietnameseDecomposition = <String, String>{
  'à': 'a\u{300}',
  'á': 'a\u{301}',
  'â': 'a\u{302}',
  'ã': 'a\u{303}',
  'è': 'e\u{300}',
  'é': 'e\u{301}',
  'ê': 'e\u{302}',
  'ì': 'i\u{300}',
  'í': 'i\u{301}',
  'î': 'i\u{302}',
  'ò': 'o\u{300}',
  'ó': 'o\u{301}',
  'ô': 'o\u{302}',
  'õ': 'o\u{303}',
  'ù': 'u\u{300}',
  'ú': 'u\u{301}',
  'û': 'u\u{302}',
  'ý': 'y\u{301}',
  'ă': 'a\u{306}',
  'ĕ': 'e\u{306}',
  'ĩ': 'i\u{303}',
  'ĭ': 'i\u{306}',
  'ŏ': 'o\u{306}',
  'ũ': 'u\u{303}',
  'ŭ': 'u\u{306}',
  'ŷ': 'y\u{302}',
  'ơ': 'o\u{31b}',
  'ư': 'u\u{31b}',
  'ṍ': 'o\u{303}\u{301}',
  'ṹ': 'u\u{303}\u{301}',
  'ạ': 'a\u{323}',
  'ả': 'a\u{309}',
  'ấ': 'a\u{302}\u{301}',
  'ầ': 'a\u{302}\u{300}',
  'ẩ': 'a\u{302}\u{309}',
  'ẫ': 'a\u{302}\u{303}',
  'ậ': 'a\u{323}\u{302}',
  'ắ': 'a\u{306}\u{301}',
  'ằ': 'a\u{306}\u{300}',
  'ẳ': 'a\u{306}\u{309}',
  'ẵ': 'a\u{306}\u{303}',
  'ặ': 'a\u{323}\u{306}',
  'ẹ': 'e\u{323}',
  'ẻ': 'e\u{309}',
  'ẽ': 'e\u{303}',
  'ế': 'e\u{302}\u{301}',
  'ề': 'e\u{302}\u{300}',
  'ể': 'e\u{302}\u{309}',
  'ễ': 'e\u{302}\u{303}',
  'ệ': 'e\u{323}\u{302}',
  'ỉ': 'i\u{309}',
  'ị': 'i\u{323}',
  'ọ': 'o\u{323}',
  'ỏ': 'o\u{309}',
  'ố': 'o\u{302}\u{301}',
  'ồ': 'o\u{302}\u{300}',
  'ổ': 'o\u{302}\u{309}',
  'ỗ': 'o\u{302}\u{303}',
  'ộ': 'o\u{323}\u{302}',
  'ớ': 'o\u{31b}\u{301}',
  'ờ': 'o\u{31b}\u{300}',
  'ở': 'o\u{31b}\u{309}',
  'ỡ': 'o\u{31b}\u{303}',
  'ợ': 'o\u{31b}\u{323}',
  'ụ': 'u\u{323}',
  'ủ': 'u\u{309}',
  'ứ': 'u\u{31b}\u{301}',
  'ừ': 'u\u{31b}\u{300}',
  'ử': 'u\u{31b}\u{309}',
  'ữ': 'u\u{31b}\u{303}',
  'ự': 'u\u{31b}\u{323}',
  'ỳ': 'y\u{300}',
  'ỵ': 'y\u{323}',
  'ỷ': 'y\u{309}',
  'ỹ': 'y\u{303}',
};
