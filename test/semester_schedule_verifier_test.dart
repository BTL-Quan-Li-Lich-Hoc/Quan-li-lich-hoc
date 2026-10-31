import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/registration_parser.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final html = File('test/fixtures/tracuu_latest.html').readAsStringSync();
  final response = jsonDecode(
    File('test/fixtures/schedule_latest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final registration = const QldtRegistrationParser().parse(
    html: html,
    selectedSemesterValue: 'new',
    selectedPlanValue: 'new-plan',
  );
  const scheduleParser = QldtParser();
  const verifier = SemesterScheduleVerifier();

  ImportedScheduleData parse(Map<String, dynamic> data) => scheduleParser
      .parseApiResponse(data, displayName: 'Sinh viên', strict: true);

  test(
    'links two study components and an exam through the registered class',
    () {
      final verified = verifier.verify(
        registration: registration,
        schedule: parse(response),
      );
      final semester = const SemesterDataBuilder().build(
        registration: registration,
        studySchedules: verified.studySchedules,
        examSchedules: verified.examSchedules,
        displayName: 'Sinh viên',
        syncedAt: DateTime(2026, 9, 23),
      );
      expect(semester.semesterId, '2026_2027_1');
      expect(semester.subjects.first.name, 'Thiết kế web nâng cao');
      expect(semester.subjects.first.studySchedules, hasLength(2));
      expect(semester.subjects.first.examSchedules, hasLength(1));
      expect(semester.subjects.last.studySchedules, isEmpty);
      expect(semester.subjects.last.examSchedules, isEmpty);
      expect(semester.toImportedScheduleData().records, hasLength(3));
    },
  );

  test('refuses an exam for a repeated subject from another term', () {
    final oldExam =
        Map<String, dynamic>.from(
            (response['Data'] as List<dynamic>).last as Map<String, dynamic>,
          )
          ..['TENLOPHOCPHAN'] = 'WEB-2025-LT'
          ..['PHONGTHI'] = 'C4';
    final mixed = <String, dynamic>{
      'Success': true,
      'Data': <dynamic>[...(response['Data'] as List<dynamic>), oldExam],
    };
    expect(
      () => verifier.verify(registration: registration, schedule: parse(mixed)),
      throwsFormatException,
    );
  });

  test('does not use a study date alone to match a class', () {
    final otherClass = Map<String, dynamic>.from(
      (response['Data'] as List<dynamic>).first as Map<String, dynamic>,
    )..['TENLOPHOCPHAN'] = 'WEB-2025-LT';
    expect(
      () => verifier.verify(
        registration: registration,
        schedule: parse(<String, dynamic>{
          'Success': true,
          'Data': <dynamic>[otherClass],
        }),
      ),
      throwsFormatException,
    );
  });

  test('cleans attendance HTML but keeps distinct registered class codes', () {
    final actual = RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: const <String>['Phân tích và thiết kế phần mềm'],
      classSections: <String, List<RegisteredClassSection>>{
        'Phân tích và thiết kế phần mềm': <RegisteredClassSection>[
          RegisteredClassSection(
            name: 'Phân tích và thiết kế phần mềm-1-1-26(N08)',
            startsOn: DateTime(2026, 8, 17),
            endsOn: DateTime(2026, 12, 1),
          ),
        ],
      },
    );
    Map<String, Object> row(String code) => <String, Object>{
      'PHANLOAI': 'LICHHOC',
      'TENHOCPHAN': 'Môn Phân tích và thiết kế phần mềm-1-1-26(N08)',
      'TENLOPHOCPHAN': '$code<br>Có mặt<br>',
      'NGAYHOC': '20/08/2026',
      'GIOBATDAU': 7,
      'PHUTBATDAU': 0,
      'GIOKETTHUC': 9,
      'PHUTKETTHUC': 0,
      'PHONGHOC_TEN': 'A1',
    };
    const code = 'Phân tích và thiết kế phần mềm-1-1-26(N08)';
    final parsed = parse(<String, dynamic>{
      'Success': true,
      'Data': <dynamic>[row(code)],
    });
    final verified = verifier.verify(registration: actual, schedule: parsed);
    expect(parsed.records.single.subjectName, 'Phân tích và thiết kế phần mềm');
    expect(parsed.records.single.className, code);
    expect(verified.studySchedules, hasLength(1));

    final other = parse(<String, dynamic>{
      'Success': true,
      'Data': <dynamic>[row('Phân tích và thiết kế phần mềm-1-1-26(N09)')],
    });
    expect(
      () => verifier.verify(registration: actual, schedule: other),
      throwsFormatException,
    );
  });

  test('rejects an old exam even if a repeated class name matches', () {
    final oldExam = Map<String, dynamic>.from(
      (response['Data'] as List<dynamic>).last as Map<String, dynamic>,
    )..['NGAYHOC'] = '10/12/2025';
    expect(
      () => verifier.verify(
        registration: registration,
        schedule: parse(<String, dynamic>{
          'Success': true,
          'Data': <dynamic>[oldExam],
        }),
      ),
      throwsFormatException,
    );
  });

  test('accepts QLĐT timetable boundaries and an exam-format label', () {
    final actual = RegisteredSemester(
      id: '2026_2027_1',
      name: '2026_2027_1',
      subjectNames: const <String>[
        'An toàn và bảo mật thông tin',
        'Lịch sử Đảng cộng sản Việt Nam',
      ],
      classSections: <String, List<RegisteredClassSection>>{
        'An toàn và bảo mật thông tin': <RegisteredClassSection>[
          RegisteredClassSection(
            name: 'An toàn và bảo mật thông tin-1-1-26(N05)',
            startsOn: DateTime(2026, 8, 24),
            endsOn: DateTime(2026, 10, 25),
          ),
        ],
        'Lịch sử Đảng cộng sản Việt Nam': <RegisteredClassSection>[
          RegisteredClassSection(
            name: 'Lịch sử Đảng cộng sản Việt Nam-1-1-26(N02).ELN',
            startsOn: DateTime(2026, 8, 17),
            endsOn: DateTime(2026, 10, 25),
          ),
        ],
      },
    );
    ScheduleRecord record(
      String id,
      String subject,
      String className,
      DateTime date, {
      bool exam = false,
    }) => ScheduleRecord(
      id: id,
      isExam: exam,
      subjectName: subject,
      className: className,
      room: 'A1',
      startAt: date,
      endAt: date.add(const Duration(hours: 1)),
    );
    final schedules = ImportedScheduleData(
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 9, 25),
      records: <ScheduleRecord>[
        record(
          'early',
          'An toàn và bảo mật thông tin',
          'An toàn và bảo mật thông tin-1-1-26(N05)',
          DateTime(2026, 8, 17),
        ),
        record(
          'late',
          'An toàn và bảo mật thông tin',
          'An toàn và bảo mật thông tin-1-1-26(N05)',
          DateTime(2026, 10, 26),
        ),
        record(
          'exam',
          'Lịch sử Đảng cộng sản Việt Nam',
          'Trắc nghiệm trên máy 30p',
          DateTime(2026, 10, 24),
          exam: true,
        ),
      ],
    );
    final verified = verifier.verify(registration: actual, schedule: schedules);
    expect(verified.studySchedules, hasLength(2));
    expect(verified.examSchedules, hasLength(1));

    final wrongClass = ImportedScheduleData(
      displayName: schedules.displayName,
      syncedAt: schedules.syncedAt,
      records: <ScheduleRecord>[
        record(
          'wrong',
          'An toàn và bảo mật thông tin',
          'An toàn và bảo mật thông tin-1-1-26(N06)',
          DateTime(2026, 9, 25),
        ),
      ],
    );
    expect(
      () => verifier.verify(registration: actual, schedule: wrongClass),
      throwsFormatException,
    );
    final distant = ImportedScheduleData(
      displayName: schedules.displayName,
      syncedAt: schedules.syncedAt,
      records: <ScheduleRecord>[
        record(
          'old',
          'An toàn và bảo mật thông tin',
          'An toàn và bảo mật thông tin-1-1-26(N05)',
          DateTime(2025, 9, 25),
        ),
      ],
    );
    expect(
      () => verifier.verify(registration: actual, schedule: distant),
      throwsFormatException,
    );
  });

  test('rejects partial or malformed API response before linking', () {
    final incomplete = <String, dynamic>{
      'Success': true,
      'Data': <dynamic>[
        (response['Data'] as List<dynamic>).first,
        <String, dynamic>{'TENHOCPHAN': 'Toán cao cấp'},
      ],
    };
    expect(() => parse(incomplete), throwsFormatException);
    expect(
      () => parse(<String, dynamic>{'Success': false}),
      throwsFormatException,
    );
    expect(
      () => const QldtRegistrationParser().parse(
        html: html.replaceAll('class="subject-item"', 'class="pending"'),
        selectedSemesterValue: 'new',
        selectedPlanValue: 'new-plan',
      ),
      throwsFormatException,
    );
  });
}
