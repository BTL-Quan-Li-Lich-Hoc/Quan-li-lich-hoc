import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Opt in only for a diagnostic build. Release APKs use the default false.
const bool qldtDiagnosticsEnabled = bool.fromEnvironment(
  'QLDT_DIAGNOSTICS',
  defaultValue: false,
);

enum QldtSyncPhase {
  session,
  navigation,
  semesterPlan,
  subjects,
  schedule,
  verification,
  sessionCache,
  save,
}

final class QldtSyncDiagnostics {
  new({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const storageKey = 'qldt_sync_diagnostics';

  /// A timing-only report. Never exports WebView responses, URLs or credentials.
  static Future<String> exportReport() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    final records = decoded is List ? decoded : const <dynamic>[];
    final safeRecords = records.take(200).whereType<Map<String, dynamic>>();
    final safe = safeRecords.map((record) {
      final phase = record['phase']?.toString() ?? '';
      final code = record['code']?.toString() ?? '';
      final request = record['request']?.toString() ?? '';
      final outcome = record['outcome']?.toString() ?? '';
      final start = DateTime.tryParse(record['startedAt']?.toString() ?? '');
      final end = DateTime.tryParse(record['endedAt']?.toString() ?? '');
      return <String, Object?>{
        'phase': QldtSyncPhase.values.any((value) => value.name == phase)
            ? phase
            : 'unknown',
        if (RegExp(r'^[A-Z_0-9]{1,60}$').hasMatch(code)) 'code': code,
        if (start != null) 'startedAt': start.toUtc().toIso8601String(),
        if (start != null && end != null)
          'durationMs': end.difference(start).inMilliseconds.clamp(0, 300000),
        if (const <String>{
          'semesters',
          'plans',
          'subjects',
          'schedule',
        }.contains(request))
          'request': request,
        if (const <String>{'success', 'error', 'exception'}.contains(outcome))
          'outcome': outcome,
        if (int.tryParse(record['elapsedMs']?.toString() ?? '') != null)
          'elapsedMs': int.parse(record['elapsedMs'].toString())
              .clamp(0, 300000),
      };
    }).toList();
    return jsonEncode(<String, Object?>{
      'version': 1,
      'kind': 'qldt_timing',
      'events': safe,
    });
  }

  static String sanitizePlanSnapshot(String raw) {
    final source = jsonDecode(raw);
    if (source is! Map ||
        source['version'] != 1 ||
        source['records'] is! List) {
      throw const FormatException('Plan diagnostics không hợp lệ.');
    }
    int count(Object? value) => value is int && value >= 0 ? value : 0;
    String id(Object? value) {
      final text = value?.toString().trim() ?? '';
      return RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(text)
          ? text
          : '[redacted]';
    }

    String? label(Object? value) {
      if (value == null) return null;
      final text = value.toString();
      if (RegExp(
        'token|cookie|authorization|session|bearer|password|mat.?khau',
        caseSensitive: false,
      ).hasMatch(text)) {
        return '[redacted]';
      }
      return text
          .substring(0, text.length > 160 ? 160 : text.length)
          .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
          .replaceAll(RegExp(r'(?:\+?\d[\d\s.-]{6,}\d)'), '[number]');
    }

    final records = (source['records'] as List).take(200).map((value) {
      final row = value is Map ? value : const <String, Object?>{};
      final keys = row['otherKeys'];
      return <String, Object?>{
        'index': count(row['index']),
        'ID': id(row['ID']),
        'DAOTAO_THOIGIANDAOTAO_ID': id(row['DAOTAO_THOIGIANDAOTAO_ID']),
        'MAKEHOACH': label(row['MAKEHOACH']),
        'TENKEHOACH': label(row['TENKEHOACH']),
        'TRANGTHAI_ID': id(row['TRANGTHAI_ID']),
        'HIEULUC': row['HIEULUC'] is bool ? row['HIEULUC'] : null,
        'otherKeys': keys is List
            ? keys
                  .whereType<String>()
                  .where((key) => RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(key))
                  .take(100)
                  .toList()
            : <String>[],
      };
    }).toList();
    final dropdown = source['dropdown'] is Map
        ? source['dropdown'] as Map
        : null;
    final options = dropdown is Map && dropdown['options'] is List
        ? (dropdown['options'] as List).take(200).map((value) {
            final option = value is Map ? value : const <String, Object?>{};
            return <String, Object?>{
              'index': count(option['index']),
              'ID': id(option['ID']),
              'label': label(option['label']),
              'selected': option['selected'] == true,
            };
          }).toList()
        : null;
    return jsonEncode(<String, Object?>{
      'version': 1,
      'latestSemesterId': id(source['latestSemesterId']),
      'latestSemesterName': label(source['latestSemesterName']),
      'recordCount': count(source['recordCount']),
      'distinctIdCount': count(source['distinctIdCount']),
      'matchingRecordIndexes': source['matchingRecordIndexes'] is List
          ? (source['matchingRecordIndexes'] as List)
                .whereType<int>()
                .where((index) => index >= 0)
                .take(200)
                .toList()
          : <int>[],
      'computedPlanIdCount': count(source['computedPlanIdCount']),
      'computedPlanIds': source['computedPlanIds'] is List
          ? (source['computedPlanIds'] as List).take(200).map(id).toList()
          : <String>[],
      'records': records,
      'dropdown': options == null
          ? null
          : <String, Object?>{
              'selectedId': id(dropdown?['selectedId']),
              'options': options,
            },
    });
  }

  final DateTime Function() _clock;
  final List<Map<String, String>> _events = [];
  Map<String, String>? _active;
  Future<void> _write = Future<void>.value();
  Future<void> get flushed => _write;

  static Future<void> appendSave(DateTime startedAt, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final previous = raw == null
        ? <dynamic>[]
        : jsonDecode(raw) as List<dynamic>;
    previous.add(<String, String>{
      'phase': QldtSyncPhase.save.name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': DateTime.now().toUtc().toIso8601String(),
      'code': code,
    });
    await prefs.setString(storageKey, jsonEncode(previous));
  }

  List<Map<String, String>> get events =>
      _events.map(Map<String, String>.from).toList();

  void start(QldtSyncPhase phase) {
    finish('OK');
    final event = <String, String>{
      'phase': phase.name,
      'startedAt': _clock().toUtc().toIso8601String(),
    };
    _events.add(event);
    _active = event;
    _persist();
  }

  void finish(String code) {
    final event = _active;
    if (event == null) return;
    event['endedAt'] = _clock().toUtc().toIso8601String();
    event['code'] = code;
    _active = null;
    _persist();
  }

  void mark(String code) {
    final now = _clock().toUtc().toIso8601String();
    _events.add(<String, String>{
      'phase': _active?['phase'] ?? 'session',
      'startedAt': now,
      'endedAt': now,
      'code': code,
    });
    _persist();
  }

  void markRequest(String request, int elapsedMs, String outcome) {
    if (!const <String>{
          'semesters',
          'plans',
          'subjects',
          'schedule',
        }.contains(request) ||
        !const <String>{'success', 'error', 'exception'}.contains(outcome)) {
      return;
    }
    final now = _clock().toUtc().toIso8601String();
    _events.add(<String, String>{
      'phase': _active?['phase'] ?? QldtSyncPhase.schedule.name,
      'startedAt': now,
      'endedAt': now,
      'code': 'REQUEST',
      'request': request,
      'outcome': outcome,
      'elapsedMs': elapsedMs.clamp(0, 300000).toString(),
    });
    _persist();
  }

  void _persist() {
    final snapshot = jsonEncode(_events);
    _write = _write
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(storageKey, snapshot);
        })
        .catchError((Object _) {});
  }
}
