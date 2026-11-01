import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_webview_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const probe = TracuuWebViewProbe();

  test('probe recognizes numeric semester options', () {
    expect(probe.script, contains(r'/^(\d{4})_(\d{4})_(\d+)$/'));
  });

  test('WebView result still passes the strict TraCuu parser', () {
    final html = File('test/fixtures/tracuu_latest.html').readAsStringSync();
    final raw = jsonEncode(<String, String>{
      'html': html,
      'semester': 'new',
      'plan': 'new-plan',
    });
    final result = probe.parseResult(raw);
    expect(result.id, '2026_2027_1');
    expect(result.subjectNames.first, 'Thiết kế web nâng cao');
    expect(result.classSections[result.subjectNames.first], hasLength(2));
    expect(
      () => probe.parseResult(raw.replaceFirst('"new-plan"', '"old-plan"')),
      throwsFormatException,
    );
  });
}
