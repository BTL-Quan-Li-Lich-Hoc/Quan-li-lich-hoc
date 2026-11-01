import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/diagnostics/qldt_sync_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production diagnostics are disabled by default', () {
    expect(qldtDiagnosticsEnabled, isFalse);
  });

  test('records only stage, time, and fixed result code', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var now = DateTime.utc(2026, 9, 24, 1);
    final trail = QldtSyncDiagnostics(clock: () => now);
    trail.start(QldtSyncPhase.schedule);
    now = now.add(const Duration(seconds: 2));
    trail.start(QldtSyncPhase.navigation);
    now = now.add(const Duration(seconds: 20));
    trail.finish('NAVIGATION_TIMEOUT');
    await trail.flushed;

    final prefs = await SharedPreferences.getInstance();
    final stored =
        (jsonDecode(prefs.getString(QldtSyncDiagnostics.storageKey)!)
                as List<dynamic>)
            .map((event) => Map<String, dynamic>.from(event as Map))
            .toList();
    expect(stored, hasLength(2));
    expect(stored[0], containsPair('code', 'OK'));
    expect(stored[1], containsPair('code', 'NAVIGATION_TIMEOUT'));
    expect(stored[1], containsPair('startedAt', '2026-09-24T01:00:02.000Z'));
    expect(stored[1], containsPair('endedAt', '2026-09-24T01:00:22.000Z'));
    expect(
      stored[1].keys,
      containsAll(<String>['phase', 'startedAt', 'endedAt', 'code']),
    );
  });

  test(
    'plan export keeps scoped fields and drops personal response values',
    () {
      final safe = QldtSyncDiagnostics.sanitizePlanSnapshot(
        jsonEncode(<String, Object?>{
          'version': 1,
          'latestSemesterId': 'semester_1',
          'recordCount': 2,
          'distinctIdCount': 2,
          'userId': 'student-private',
          'cookie': 'secret-cookie',
          'records': <Map<String, Object?>>[
            <String, Object?>{
              'index': 0,
              'ID': 'plan_1',
              'DAOTAO_THOIGIANDAOTAO_ID': 'semester_1',
              'MAKEHOACH': 'contact@example.com 0912345678',
              'TENKEHOACH': 'Kế hoạch học kỳ',
              'NGUOITAO_ID': 'private-student-id',
              'otherKeys': <String>['NGUOITAO_ID'],
            },
          ],
          'dropdown': <String, Object?>{
            'selectedId': 'plan_1',
            'options': <Map<String, Object?>>[
              <String, Object?>{
                'index': 0,
                'ID': 'plan_1',
                'label': 'Kế hoạch học kỳ',
                'selected': true,
              },
            ],
          },
        }),
      );
      expect(safe, contains('plan_1'));
      expect(safe, contains('"distinctIdCount":2'));
      expect(safe, contains('NGUOITAO_ID'));
      for (final secret in <String>[
        'student-private',
        'secret-cookie',
        'private-student-id',
        'contact@example.com',
        '0912345678',
      ]) {
        expect(safe, isNot(contains(secret)));
      }
    },
  );
}
