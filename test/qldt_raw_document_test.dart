import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_raw_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts supported QLĐT JSON list fields', () {
    for (final key in <String>['Data', 'schedule', 'rows']) {
      final document = QldtRawDocument.fromJsonText('{"$key":[]}');
      expect(document.text, contains(key));
    }
  });

  test('rejects invalid or oversized payloads', () {
    expect(
      () => QldtRawDocument.fromJsonText('{"items":[]}'),
      throwsFormatException,
    );
    expect(() => QldtRawDocument.fromJsonText('[]'), throwsFormatException);
  });
}
