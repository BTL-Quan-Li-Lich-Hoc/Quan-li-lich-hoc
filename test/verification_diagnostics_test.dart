import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/diagnostics/verification_diagnostics.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration scope includes only plan and semester identifiers', () {
    final planId = List<String>.filled(32, 'A').join();
    final semesterId = List<String>.filled(32, 'B').join();
    final raw = jsonEncode(<String, Object?>{
      'registrations': <String, Object?>{
        'Data': <Map<String, Object?>>[
          <String, Object?>{
            'DANGKY_KEHOACHDANGKY_ID': planId,
            'DAOTAO_THOIGIANDAOTAO_ID': semesterId,
            'HOTEN': 'Private Student',
            'TOKEN': 'private-token',
          },
        ],
      },
    });
    final report = jsonDecode(
      const VerificationDiagnostics().captureRegistrationScope(raw),
    ) as Map<String, dynamic>;
    expect(report['rowCount'], 1);
    expect(report['planIds'], <String>[planId]);
    expect(report['semesterIds'], <String>[semesterId]);
    expect(jsonEncode(report), isNot(contains('Private Student')));
    expect(jsonEncode(report), isNot(contains('private-token')));
  });

  test('identifies the failing class without copying account data', () {
    final registration = RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: const <String>['Thiết kế web nâng cao'],
      classSections: <String, List<RegisteredClassSection>>{
        'Thiết kế web nâng cao': <RegisteredClassSection>[
          RegisteredClassSection(
            name: 'WEB-LT',
            startsOn: DateTime(2026, 8, 17),
            endsOn: DateTime(2026, 11),
          ),
        ],
      },
    );
    final schedule = ImportedScheduleData(
      displayName: 'Private Student',
      records: <ScheduleRecord>[
        ScheduleRecord(
          id: 'private-id',
          isExam: false,
          subjectName: 'Thiết kế web nâng cao',
          className: 'WEB-TH',
          room: 'Private Room',
          startAt: DateTime(2026, 9, 24, 7),
          endAt: DateTime(2026, 9, 24, 9),
        ),
      ],
      syncedAt: DateTime(2026, 9, 24),
    );
    final raw = const VerificationDiagnostics().capture(
      registration: registration,
      schedule: schedule,
    );
    final report = jsonDecode(raw) as Map<String, dynamic>;
    final issue = (report['issues'] as List).single as Map<String, dynamic>;
    expect(issue['reason'], 'class_name_mismatch');
    expect(issue['scheduleClass'], 'WEB-TH');
    expect(issue['registeredClasses'], <String>['WEB-LT']);
    expect(raw, isNot(contains('Private Student')));
    expect(raw, isNot(contains('Private Room')));
    expect(raw, isNot(contains('private-id')));
  });
}
