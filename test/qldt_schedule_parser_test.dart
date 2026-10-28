import 'package:better_phenikaa_schedule/features/timetable/domain/qldt_schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits lesson and exam; strips Môn prefix', () {
    const raw = '''{"Data":[
      {"PHANLOAI":"LICHHOC","TENHOCPHAN":"Môn Toán cao cấp","NGAYHOC":"22/10/2026","GIOBATDAU":7,"GIOKETTHUC":9,"PHONGHOC_TEN":"A1"},
      {"PHANLOAI":"LICHTHI","TENHOCPHAN":"Môn Toán cao cấp","NGAYHOC":"10/12/2026","GIOBATDAU":8,"GIOKETTHUC":10,"PHONGTHI":"B2"}
    ]}''';
    final result = QldtScheduleParser.parse(raw, receivedAt: DateTime(2026, 10, 22));
    expect(result.classes.single.subjectName, 'Toán cao cấp');
    expect(result.exams.single.room, 'B2');
    expect(result.classes.single.startAt.hour, 7);
  });
  test('rejects bad data instead of replacing cache', () {
    expect(() => QldtScheduleParser.parse('{"Data":[{"TENHOCPHAN":"A"}]}'), throwsFormatException);
  });
}
