import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class ScheduleDifference {
  const new({
    required this.added,
    required this.removed,
    required this.modified,
    this.details = const <ScheduleChange>[],
  });

  factory fromJson(Map<String, dynamic> json) => ScheduleDifference(
    added: json['added'] as int,
    removed: json['removed'] as int,
    modified: json['modified'] as int,
    details: (json['details'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) =>
              ScheduleChange.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
  );

  final int added;
  final int removed;
  final int modified;
  final List<ScheduleChange> details;

  bool get hasChanges => added + removed + modified > 0;

  Map<String, Object> toJson() => <String, Object>{
    'added': added,
    'removed': removed,
    'modified': modified,
    'details': details.map((item) => item.toJson()).toList(),
  };
}

final class ScheduleChange {
  const new({required this.kind, this.before, this.after});

  factory fromJson(Map<String, dynamic> json) => ScheduleChange(
    kind: json['kind'] as String,
    before: json['before'] == null
        ? null
        : ScheduleRecord.fromJson(
            Map<String, Object?>.from(json['before'] as Map),
          ),
    after: json['after'] == null
        ? null
        : ScheduleRecord.fromJson(
            Map<String, Object?>.from(json['after'] as Map),
          ),
  );

  final String kind;
  final ScheduleRecord? before;
  final ScheduleRecord? after;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'before': before?.toJson(),
    'after': after?.toJson(),
  };
}

final class SemesterDifference {
  const new({
    required this.initial,
    required this.addedSubjects,
    required this.removedSubjects,
    required this.study,
    required this.exams,
  });

  factory fromJson(Map<String, dynamic> json) => SemesterDifference(
    initial: json['initial'] as bool,
    addedSubjects: (json['addedSubjects'] as List<dynamic>).cast<String>(),
    removedSubjects: (json['removedSubjects'] as List<dynamic>).cast<String>(),
    study: ScheduleDifference.fromJson(
      Map<String, dynamic>.from(json['study'] as Map<dynamic, dynamic>),
    ),
    exams: ScheduleDifference.fromJson(
      Map<String, dynamic>.from(json['exams'] as Map<dynamic, dynamic>),
    ),
  );

  final bool initial;
  final List<String> addedSubjects;
  final List<String> removedSubjects;
  final ScheduleDifference study;
  final ScheduleDifference exams;

  bool get hasChanges =>
      !initial &&
      (addedSubjects.isNotEmpty ||
          removedSubjects.isNotEmpty ||
          study.hasChanges ||
          exams.hasChanges);

  Map<String, Object> toJson() => <String, Object>{
    'initial': initial,
    'addedSubjects': addedSubjects,
    'removedSubjects': removedSubjects,
    'study': study.toJson(),
    'exams': exams.toJson(),
  };
}

final class SemesterDifferenceStore {
  static const storageKey = 'better_phenikaa_semester_difference_v1';

  Future<SemesterDifference?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    return raw == null
        ? null
        : SemesterDifference.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
          );
  }

  Future<void> save(SemesterDifference difference) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      storageKey,
      jsonEncode(difference.toJson()),
    )) {
      throw StateError('Không thể lưu kết quả đồng bộ.');
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(storageKey)) {
      throw StateError('Không thể xóa kết quả đồng bộ.');
    }
  }
}

final class SemesterChangeDetector {
  const new();

  SemesterDifference compare(CurrentSemester? previous, CurrentSemester next) {
    if (previous == null) {
      return const SemesterDifference(
        initial: true,
        addedSubjects: <String>[],
        removedSubjects: <String>[],
        study: ScheduleDifference(added: 0, removed: 0, modified: 0),
        exams: ScheduleDifference(added: 0, removed: 0, modified: 0),
      );
    }

    final oldSubjects = {
      for (final item in previous.subjects) item.subjectId: item,
    };
    final newSubjects = {
      for (final item in next.subjects) item.subjectId: item,
    };
    final sharedIds = oldSubjects.keys.toSet().intersection(
      newSubjects.keys.toSet(),
    );
    final oldStudy = <ScheduleRecord>[];
    final newStudy = <ScheduleRecord>[];
    final oldExams = <ScheduleRecord>[];
    final newExams = <ScheduleRecord>[];
    for (final id in sharedIds) {
      oldStudy.addAll(oldSubjects[id]!.studySchedules);
      newStudy.addAll(newSubjects[id]!.studySchedules);
      oldExams.addAll(oldSubjects[id]!.examSchedules);
      newExams.addAll(newSubjects[id]!.examSchedules);
    }
    final study = _compareRows(oldStudy, newStudy);
    final exams = _compareRows(oldExams, newExams);
    return SemesterDifference(
      initial: false,
      addedSubjects: next.subjects
          .where((item) => !oldSubjects.containsKey(item.subjectId))
          .map((item) => item.name)
          .toList(),
      removedSubjects: previous.subjects
          .where((item) => !newSubjects.containsKey(item.subjectId))
          .map((item) => item.name)
          .toList(),
      study: ScheduleDifference(
        added:
            study.added +
            next.subjects
                .where((item) => !oldSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.studySchedules.length),
        removed:
            study.removed +
            previous.subjects
                .where((item) => !newSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.studySchedules.length),
        modified: study.modified,
        details: <ScheduleChange>[
          ...study.details,
          for (final item in next.subjects.where(
            (item) => !oldSubjects.containsKey(item.subjectId),
          ))
            for (final row in item.studySchedules)
              ScheduleChange(kind: 'added', after: row),
          for (final item in previous.subjects.where(
            (item) => !newSubjects.containsKey(item.subjectId),
          ))
            for (final row in item.studySchedules)
              ScheduleChange(kind: 'removed', before: row),
        ],
      ),
      exams: ScheduleDifference(
        added:
            exams.added +
            next.subjects
                .where((item) => !oldSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.examSchedules.length),
        removed:
            exams.removed +
            previous.subjects
                .where((item) => !newSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.examSchedules.length),
        modified: exams.modified,
        details: <ScheduleChange>[
          ...exams.details,
          for (final item in next.subjects.where(
            (item) => !oldSubjects.containsKey(item.subjectId),
          ))
            for (final row in item.examSchedules)
              ScheduleChange(kind: 'added', after: row),
          for (final item in previous.subjects.where(
            (item) => !newSubjects.containsKey(item.subjectId),
          ))
            for (final row in item.examSchedules)
              ScheduleChange(kind: 'removed', before: row),
        ],
      ),
    );
  }

  ScheduleDifference _compareRows(
    List<ScheduleRecord> old,
    List<ScheduleRecord> next,
  ) {
    final remaining = [...next];
    final unmatched = <ScheduleRecord>[];
    for (final row in old) {
      final match = remaining.indexWhere((item) => _sameContent(row, item));
      if (match < 0) {
        unmatched.add(row);
      } else {
        remaining.removeAt(match);
      }
    }
    var modified = 0;
    final details = <ScheduleChange>[];
    for (final row in unmatched.toList()) {
      final sameDay = remaining.indexWhere(
        (item) =>
            _name(item.subjectName) == _name(row.subjectName) &&
            _day(item.startAt) == _day(row.startAt),
      );
      final match = sameDay >= 0
          ? sameDay
          : remaining.length == 1 &&
                unmatched.length == 1 &&
                _name(remaining.first.subjectName) == _name(row.subjectName)
          ? 0
          : -1;
      if (match >= 0) {
        modified++;
        details.add(
          ScheduleChange(
            kind: 'modified',
            before: row,
            after: remaining[match],
          ),
        );
        remaining.removeAt(match);
        unmatched.remove(row);
      }
    }
    return ScheduleDifference(
      added: remaining.length,
      removed: unmatched.length,
      modified: modified,
      details: <ScheduleChange>[
        ...details,
        for (final row in remaining) ScheduleChange(kind: 'added', after: row),
        for (final row in unmatched)
          ScheduleChange(kind: 'removed', before: row),
      ],
    );
  }

  bool _sameContent(ScheduleRecord a, ScheduleRecord b) =>
      _name(a.subjectName) == _name(b.subjectName) &&
      _name(a.className) == _name(b.className) &&
      _name(a.room) == _name(b.room) &&
      _name(a.examForm) == _name(b.examForm) &&
      a.startAt == b.startAt &&
      a.endAt == b.endAt &&
      a.periodStart == b.periodStart &&
      a.periodEnd == b.periodEnd;

  String _name(String value) => normalizeSubjectName(value);

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
