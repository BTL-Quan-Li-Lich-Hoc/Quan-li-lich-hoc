import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains distinct component classes at the same time and room', () {
    Map<String, Object> item(String section) => <String, Object>{
      'PHANLOAI': 'LICHHOC',
      'TENHOCPHAN': 'Thiết kế web nâng cao',
      'TENLOPHOCPHAN': section,
      'NGAYHOC': '23/09/2026',
      'GIOBATDAU': 7,
      'PHUTBATDAU': 0,
      'GIOKETTHUC': 9,
      'PHUTKETTHUC': 0,
      'PHONGHOC_TEN': 'A1',
    };
    final data = const QldtParser().parseApiResponse(
      <String, dynamic>{
        'Success': true,
        'Data': <dynamic>[item('WEB-LT'), item('WEB-TH')],
      },
      displayName: 'Sinh viên',
      strict: true,
    );
    expect(data.records, hasLength(2));
    expect(data.records.map((row) => row.id).toSet(), hasLength(2));
  });

  const parser = QldtParser();

  test('extracts the display name from the QLĐT account element', () {
    const html = '''
      <div class="nav-account">
        <span id="lblHoTenNguoiDangNhap">Sinh Viên Demo</span>
      </div>
    ''';

    expect(parser.parseDisplayName(html), 'Sinh Viên Demo');
  });

  test('keeps QLĐT student-name token order for every account', () {
    const names = <String>[
      'Nguyễn Minh Đạo',
      'Trần Thị Mai',
      'Lê Nguyễn Gia Huy',
      'Đỗ Hoàng Gia Bảo',
    ];

    for (final name in names) {
      final html =
          '<span id="lblHoTenNguoiDangNhap">$name</span>';
      expect(parser.parseDisplayName(html), name);
    }
  });

  test('returns the exact real QLĐT HTML name without normalization', () {
    const html = '''
      <li class="img-user">
        <span id="lblHoTenNguoiDangNhap">NguyễN Minh ĐạO</span>
      </li>
    ''';

    expect(parser.parseDisplayName(html), 'NguyễN Minh ĐạO');
  });

  test('does not treat generic account display names as student names', () {
    const html = '''
      <div class="nav-account">
        <button><span>Microsoft Display Name</span></button>
      </div>
    ''';

    expect(parser.parseDisplayName(html), isEmpty);
  });

  test('separates study schedule and exam schedule using PHANLOAI', () {
    final parsed = parser.parseApiResponse(<String, dynamic>{
      'Success': true,
      'Data': <Map<String, dynamic>>[
        <String, dynamic>{
          'PHANLOAI': 'LICHHOC',
          'NGAYHOC': '26/08/2026',
          'TENHOCPHAN': 'Thiết kế web nâng cao',
          'PHONGHOC_TEN': 'A6-101',
          'GIOBATDAU': 6,
          'PHUTBATDAU': 45,
          'GIOKETTHUC': 9,
          'PHUTKETTHUC': 25,
        },
        <String, dynamic>{
          'PHANLOAI': 'LICHTHI',
          'NGAYHOC': '26/08/2026',
          'TENHOCPHAN': 'Lập trình C++',
          'PHONGTHI': 'A6-201',
          'GIOBATDAU': 7,
          'PHUTBATDAU': 30,
          'GIOKETTHUC': 9,
          'PHUTKETTHUC': 0,
        },
      ],
    }, displayName: 'Sinh Viên Demo');

    expect(parsed.displayName, 'Sinh Viên Demo');
    expect(parsed.classes, hasLength(1));
    expect(parsed.exams, hasLength(1));
    expect(parsed.classes.single.subjectName, 'Thiết kế web nâng cao');
    expect(parsed.exams.single.room, 'A6-201');
  });

  test('local snapshot JSON round-trip preserves records', () {
    final original = ImportedScheduleData(
      displayName: 'Sinh Viên Demo',
      syncedAt: DateTime(2026, 9, 9, 14),
      records: <ScheduleRecord>[
        ScheduleRecord(
          id: 'one',
          isExam: false,
          subjectName: 'Lập trình mobile',
          room: 'A6-205',
          startAt: DateTime(2026, 8, 26, 9, 30),
          endAt: DateTime(2026, 8, 26, 12, 10),
        ),
      ],
    );

    final restored = ImportedScheduleData.decode(original.encode());
    expect(restored.displayName, original.displayName);
    expect(restored.records.single.room, 'A6-205');
    expect(restored.records.single.startAt, DateTime(2026, 8, 26, 9, 30));
  });
}
