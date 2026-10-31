import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/registration_parser.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = QldtRegistrationParser();
  const html = '''
    <select id="dropSearch_HocKy">
      <option value="">Chọn học kỳ</option>
      <option value="previous">2025_2026_3</option>
      <option value="latest">2026_2027_1</option>
    </select>
    <select id="dropSearch_KeHoach">
      <option value="old-plan">2025_2026_3,1 Đăng ký HK3</option>
      <option value="latest-plan">2026_2027_1,1 Đăng ký HK1</option>
    </select>
    <div id="zoneKetQuaDangKy">
      <div class="subject-item">
        <div><h4>Môn Lập trình C++</h4></div>
        <div class="classroom-section-item">
          <a class="btnChiTietLopHocPhan">C++-LT</a>
          <div class="classroom-day">17/08/2026 - 01/11/2026</div>
        </div>
        <div class="classroom-section-item">
          <a class="btnChiTietLopHocPhan">C++-TH</a>
          <div class="classroom-day">24/08/2026 - 25/10/2026</div>
        </div>
      </div>
      <div class="subject-item"><div><h4>Toán cao cấp</h4></div></div>
    </div>
  ''';

  test('uses semester chronology and groups class components by subject', () {
    final semester = parser.parse(
      html: html,
      selectedSemesterValue: 'latest',
      selectedPlanValue: 'latest-plan',
    );
    expect(semester.id, '2026_2027_1');
    expect(semester.subjectNames, <String>['Lập trình C++', 'Toán cao cấp']);
    expect(semester.classSections['Lập trình C++'], hasLength(2));
    expect(semester.classSections['Lập trình C++']!.first.name, 'C++-LT');
    expect(
      semester.classSections['Lập trình C++']!.first.startsOn,
      DateTime(2026, 8, 17),
    );
    expect(semester.classSections['Toán cao cấp'], isEmpty);
  });

  test('rejects DOM results that still belong to another semester', () {
    expect(
      () => parser.parse(
        html: html,
        selectedSemesterValue: 'previous',
        selectedPlanValue: 'old-plan',
      ),
      throwsFormatException,
    );
  });

  test('rejects a registration plan from another semester', () {
    expect(
      () => parser.parse(
        html: html,
        selectedSemesterValue: 'latest',
        selectedPlanValue: 'old-plan',
      ),
      throwsFormatException,
    );
  });

  test('rejects an unloaded registration result', () {
    expect(
      () => parser.parse(
        html: html.replaceAll('class="subject-item"', 'class="pending"'),
        selectedSemesterValue: 'latest',
        selectedPlanValue: 'latest-plan',
      ),
      throwsFormatException,
    );
  });

  test('rejects an incomplete class date range', () {
    expect(
      () => parser.parse(
        html: html.replaceFirst('17/08/2026 - 01/11/2026', 'Đang tải'),
        selectedSemesterValue: 'latest',
        selectedPlanValue: 'latest-plan',
      ),
      throwsFormatException,
    );
  });

  test(
    'removes only the TraCuu heading label and preserves subject accents',
    () {
      final semester = parser.parse(
        html: html.replaceFirst(
          'Môn Lập trình C++',
          'mÔn  Thiết kế web nâng cao',
        ),
        selectedSemesterValue: 'latest',
        selectedPlanValue: 'latest-plan',
      );
      expect(semester.subjectNames.first, 'Thiết kế web nâng cao');
      expect(semester.classSections['Thiết kế web nâng cao'], hasLength(2));
      expect(semester.subjectNames.last, 'Toán cao cấp');
    },
  );

  test('matches a normalized QLĐT name without fuzzy matching', () {
    final registration = parser.parse(
      html: html.replaceFirst('Môn Lập trình C++', 'Môn Thiết kế web nâng cao'),
      selectedSemesterValue: 'latest',
      selectedPlanValue: 'latest-plan',
    );
    ScheduleRecord row(String name) => ScheduleRecord(
      id: 'one-class',
      isExam: false,
      subjectName: name,
      room: 'A1',
      startAt: DateTime(2026, 9, 23, 7),
      endAt: DateTime(2026, 9, 23, 9),
    );

    final current = const SemesterDataBuilder().build(
      registration: registration,
      studySchedules: <ScheduleRecord>[row(' THIẾT   KẾ WEB NÂNG CAO ')],
      examSchedules: const <ScheduleRecord>[],
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 9, 23),
    );
    expect(current.subjects.first.name, 'Thiết kế web nâng cao');
    expect(current.subjects.first.studySchedules, hasLength(1));
    expect(
      () => const SemesterDataBuilder().build(
        registration: registration,
        studySchedules: <ScheduleRecord>[row('Thiết kế web nâng cao 2')],
        examSchedules: const <ScheduleRecord>[],
        displayName: 'Sinh viên',
        syncedAt: DateTime(2026, 9, 23),
      ),
      throwsFormatException,
    );
  });
}
