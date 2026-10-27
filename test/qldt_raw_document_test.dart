import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_raw_document.dart';
import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_webview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts QLDT-shaped JSON', () {
    expect(QldtRawDocument.fromJsonText('{"Data":[]}').text, contains('Data'));
    expect(() => QldtRawDocument.fromJsonText('{"hello":[]}'), throwsFormatException);
  });
  test('webview only accepts university https domain', () {
    expect(QldtWebViewPage.isAllowed('https://qldt.phenikaa-uni.edu.vn/'), isTrue);
    expect(QldtWebViewPage.isAllowed('http://phenikaa-uni.edu.vn/'), isFalse);
    expect(QldtWebViewPage.isAllowed('https://phenikaa-uni.edu.vn.evil.example/'), isFalse);
  });
}
