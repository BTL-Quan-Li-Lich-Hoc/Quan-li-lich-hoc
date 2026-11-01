import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/tro_li/assistant_catalog.dart';
import 'package:better_phenikaa_schedule/features/tro_li/assistant_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all packs persist through a new selection load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(await AssistantSelection.load(), AssistantPack.normal);
    expect(AssistantPack.values, hasLength(8));
    for (final pack in AssistantPack.values) {
      await AssistantSelection.save(pack);
      expect(await AssistantSelection.load(), pack);
    }
  });

  test('all approved lines are copied verbatim into the catalog', () {
    final source = jsonDecode(
      File('tool/assistant_pack_texts.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final pack in AssistantPack.values) {
      final lines = source[pack.name] as Map<String, dynamic>;
      expect(assistantCatalog[pack.name], hasLength(18));
      for (var number = 1; number <= 18; number++) {
        expect(assistantCatalog[pack.name]![number], lines['U$number']);
      }
    }
  });

  test('dynamic use cases keep required placeholders in every pack', () {
    for (final pack in AssistantPack.values) {
      expect(
        assistantCatalog[pack.name]![9],
        contains('X'),
        reason: '${pack.name} U9 must keep X',
      );
      expect(
        assistantCatalog[pack.name]![11],
        allOf(contains('X'), contains('N')),
        reason: '${pack.name} U11 must keep X and N',
      );
    }
  });

  test('each existing event resolves to the approved use case', () {
    final cases = <(AssistantEvent, int, int, int)>[
      (AssistantEvent.syncStale, 1, 0, 1),
      (AssistantEvent.syncSuccessNoChange, 2, 0, 1),
      (AssistantEvent.studyChanged, 3, 0, 1),
      (AssistantEvent.examChanged, 4, 0, 1),
      (AssistantEvent.studyAndExamChanged, 5, 0, 1),
      (AssistantEvent.examInDays, 6, 7, 1),
      (AssistantEvent.examInDays, 7, 3, 1),
      (AssistantEvent.examTomorrow, 8, 1, 1),
      (AssistantEvent.examInDays, 9, 5, 1),
      (AssistantEvent.examPeriodActive, 10, 0, 1),
      (AssistantEvent.examCountdownMultiple, 11, 5, 2),
      (AssistantEvent.widgetSyncChanged, 12, 0, 1),
      (AssistantEvent.widgetSyncUnchanged, 13, 0, 1),
      (AssistantEvent.differenceUnread, 14, 0, 1),
      (AssistantEvent.examEmpty, 15, 0, 1),
      (AssistantEvent.studyTodayEmpty, 16, 0, 1),
      (AssistantEvent.syncFailed, 17, 0, 1),
      (AssistantEvent.syncTimeout, 18, 0, 1),
    ];
    for (final pack in AssistantPack.values) {
      for (final (event, useCase, days, count) in cases) {
        final expected = assistantCatalog[pack.name]![useCase]!
            .replaceAll(useCase == 9 || useCase == 11 ? 'X' : '\u0000', '$days')
            .replaceAll(useCase == 11 ? 'N' : '\u0000', '$count');
        expect(
          AssistantText.of(event, pack, days: days, examCount: count),
          expected,
          reason: '${pack.name} U$useCase',
        );
      }
    }
  });

  test('missing pack entry falls back to normal', () {
    final fallback = <String, Map<int, String>>{
      'normal': assistantCatalog['normal']!,
      'academic': <int, String>{},
    };
    expect(
      AssistantText.of(
        AssistantEvent.syncStale,
        AssistantPack.academic,
        templates: fallback,
      ),
      assistantCatalog['normal']![1],
    );
  });

  test('flirtatious widget text uses <3, other surfaces keep the heart', () {
    final outside = AssistantText.of(
      AssistantEvent.examEmpty,
      AssistantPack.flirtatious,
    );
    final widget = AssistantText.of(
      AssistantEvent.examEmpty,
      AssistantPack.flirtatious,
      inWidget: true,
    );
    expect(outside, contains('❤️'));
    expect(widget, contains('<3'));
    expect(widget, isNot(contains('❤️')));
  });
}
