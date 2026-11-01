import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:html/parser.dart' as html_parser;

final class ScheduleRecord {
  const new({
    required this.id,
    required this.isExam,
    required this.subjectName,
    required this.room,
    required this.startAt,
    required this.endAt,
    this.className = '',
    this.examForm = '',
    this.periodStart,
    this.periodEnd,
  });

  factory fromJson(Map<String, Object?> json) {
    return ScheduleRecord(
      id: json['id']! as String,
      isExam: json['isExam']! as bool,
      subjectName: json['subjectName']! as String,
      room: json['room']! as String,
      startAt: DateTime.parse(json['startAt']! as String),
      endAt: DateTime.parse(json['endAt']! as String),
      className: json['className'] as String? ?? '',
      examForm: json['examForm'] as String? ?? '',
      periodStart: json['periodStart'] as int?,
      periodEnd: json['periodEnd'] as int?,
    );
  }

  final String id;
  final bool isExam;
  final String subjectName;
  final String room;
  final DateTime startAt;
  final DateTime endAt;
  final String className;
  final String examForm;
  final int? periodStart;
  final int? periodEnd;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'isExam': isExam,
    'subjectName': subjectName,
    'room': room,
    'startAt': startAt.toIso8601String(),
    'endAt': endAt.toIso8601String(),
    'className': className,
    'examForm': examForm,
    'periodStart': periodStart,
    'periodEnd': periodEnd,
  };
}

final class ImportedScheduleData {
  const new({
    required this.displayName,
    required this.records,
    required this.syncedAt,
    this.source = 'qldt',
  });

  factory decode(String source) {
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final recordsRaw = raw['records'] as List<dynamic>? ?? const <dynamic>[];
    return ImportedScheduleData(
      displayName: raw['displayName'] as String? ?? '',
      records: recordsRaw
          .map(
            (item) => ScheduleRecord.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
      syncedAt: DateTime.parse(raw['syncedAt']! as String),
      source: raw['source'] as String? ?? 'qldt',
    );
  }

  final String displayName;
  final List<ScheduleRecord> records;
  final DateTime syncedAt;
  final String source;

  Iterable<ScheduleRecord> get classes =>
      records.where((record) => !record.isExam);

  Iterable<ScheduleRecord> get exams =>
      records.where((record) => record.isExam);

  Map<String, Object?> toJson() => <String, Object?>{
    'displayName': displayName,
    'records': records.map((record) => record.toJson()).toList(),
    'syncedAt': syncedAt.toIso8601String(),
    'source': source,
  };

  String encode() => jsonEncode(toJson());
}

final class QldtParser {
  const new();

  String parseDisplayName(String html) {
    final document = html_parser.parse(html);
    final preferred = document.querySelector('#lblHoTenNguoiDangNhap');
    return preferred?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  }

  ImportedScheduleData parseLiveEnvelope(
    String envelopeJson, {
    bool strict = false,
  }) {
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    var displayName = (envelope['name'] as String? ?? '').trim();
    final response = envelope['response'];
    if (response is! Map) {
      throw const FormatException('QLĐT response is not an object.');
    }
    final mappedResponse = Map<String, dynamic>.from(response);
    if (displayName.isEmpty) {
      displayName = _displayNameFromResponse(mappedResponse);
    }
    return parseApiResponse(
      mappedResponse,
      displayName: displayName,
      strict: strict,
    );
  }

  ImportedScheduleData parseApiResponse(
    Map<String, dynamic> response, {
    required String displayName,
    bool strict = false,
  }) {
    if (response['Success'] != true) {
      throw const FormatException('QLĐT returned Success != true.');
    }
    final rawData = response['Data'];
    if (rawData is! List) {
      throw const FormatException('QLĐT Data is not a list.');
    }

    final recordsById = <String, ScheduleRecord>{};
    for (final rawItem in rawData) {
      if (rawItem is! Map) {
        if (strict) {
          throw const FormatException('QLĐT có bản ghi không hợp lệ.');
        }
        continue;
      }
      final item = Map<String, dynamic>.from(rawItem);
      if (strict &&
          !<String>{
            'LICHHOC',
            'LICHTHI',
          }.contains(_string(item['PHANLOAI']).toUpperCase())) {
        throw const FormatException('QLĐT có loại lịch không xác định.');
      }
      final record = _parseRecord(item);
      if (record != null) {
        recordsById[record.id] = record;
      } else if (strict) {
        throw const FormatException('QLĐT có bản ghi thiếu trường bắt buộc.');
      }
    }

    if (rawData.isNotEmpty && recordsById.isEmpty) {
      throw const FormatException('Không có bản ghi QLĐT hợp lệ.');
    }

    final records = recordsById.values.toList();
    records.sort((a, b) => a.startAt.compareTo(b.startAt));
    return ImportedScheduleData(
      displayName: displayName,
      records: records,
      syncedAt: DateTime.now(),
    );
  }

  ScheduleRecord? _parseRecord(Map<String, dynamic> item) {
    final subjectName = subjectDisplayName(_string(item['TENHOCPHAN']));
    final dateText = _string(item['NGAYHOC']);
    if (subjectName.isEmpty || dateText.isEmpty) {
      return null;
    }

    final day = _parseVietnameseDate(dateText);
    if (day == null) {
      return null;
    }

    final startHour = _int(item['GIOBATDAU']);
    final startMinute = _int(item['PHUTBATDAU']);
    final endHour = _int(item['GIOKETTHUC']);
    final endMinute = _int(item['PHUTKETTHUC']);
    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return null;
    }
    if (startHour < 0 ||
        startHour > 23 ||
        endHour < 0 ||
        endHour > 23 ||
        startMinute < 0 ||
        startMinute > 59 ||
        endMinute < 0 ||
        endMinute > 59) {
      return null;
    }

    final isExam = _string(item['PHANLOAI']).toUpperCase() == 'LICHTHI';
    final room = isExam
        ? _firstNonEmpty(<Object?>[item['PHONGHOC_TEN'], item['PHONGTHI']])
        : _firstNonEmpty(<Object?>[item['PHONGHOC_TEN'], item['TENPHONGHOC']]);
    final className = _string(item['TENLOPHOCPHAN'])
        .split(RegExp(r'<br\s*/?>', caseSensitive: false))
        .first
        .trim();
    final examForm = _string(item['DANGKY_LOPHOCPHAN_TEN']);
    final startAt = DateTime(
      day.year,
      day.month,
      day.day,
      startHour,
      startMinute,
    );
    final endAt = DateTime(day.year, day.month, day.day, endHour, endMinute);
    if (!endAt.isAfter(startAt)) {
      return null;
    }
    final id = <String>[
      if (isExam) 'exam' else 'class',
      dateText,
      subjectName,
      '$startHour:$startMinute',
      room,
      className,
    ].join('|');

    return ScheduleRecord(
      id: id,
      isExam: isExam,
      subjectName: subjectName,
      room: room,
      startAt: startAt,
      endAt: endAt,
      className: className,
      examForm: examForm,
      periodStart: _int(item['TIETBATDAU']),
      periodEnd: _int(item['TIETKETTHUC']),
    );
  }

  static DateTime? _parseVietnameseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String _displayNameFromResponse(
    Map<String, dynamic> response,
  ) {
    const exactKeys = <String>{
      'HOTEN',
      'HO_TEN',
      'HOVATEN',
      'TENNGUOIHOC',
      'NGUOIHOC_TEN',
      'QLSV_NGUOIHOC_TEN',
      'SINHVIEN_TEN',
      'TEN_SINHVIEN',
      'FULLNAME',
      'FULL_NAME',
    };

    String? walk(Object? node, [int depth = 0]) {
      if (node == null || depth > 6) return null;
      if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key.toString().trim().toUpperCase();
          final compact = key.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final looksLikeStudentName =
              exactKeys.contains(key) ||
              compact == 'HOTEN' ||
              compact == 'HOVATEN' ||
              compact == 'TENNGUOIHOC' ||
              compact == 'NGUOIHOTEN' ||
              compact == 'SINHVIENTEN' ||
              compact == 'TENSINHVIEN' ||
              (compact.contains('NGUOIHOC') && compact.endsWith('TEN'));
          if (looksLikeStudentName) {
            final value = _string(entry.value);
            if (value.isNotEmpty && value.length <= 120) return value;
          }
        }
        for (final value in node.values) {
          final found = walk(value, depth + 1);
          if (found != null && found.isNotEmpty) return found;
        }
      } else if (node is List) {
        for (final value in node) {
          final found = walk(value, depth + 1);
          if (found != null && found.isNotEmpty) return found;
        }
      }
      return null;
    }

    return walk(response)?.trim() ?? '';
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
