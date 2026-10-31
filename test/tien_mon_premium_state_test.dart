import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/background/tien_mon_background.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_engine.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_safe_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual scene transitions wrap and auto resolves without replacing controller', () {
    final controller = TienMonSceneController(
      clock: () => DateTime(2026, 9, 29, 17, 30),
    );
    final identity = controller;

    controller.select(8);
    controller.next();
    expect(controller.scene, 1);
    expect(identical(identity, controller), isTrue);

    controller.useAutomatic();
    expect(controller.scene, 5);
    expect(controller.automatic, isTrue);
    controller.dispose();
  });

  test('fake adapter stays behind production independent contract', () {
    const adapter = TienMonDemoScheduleAdapter();
    final week = adapter.loadWeek(
      anchor: DateTime(2026, 9, 29),
      mode: TienMonScheduleMode.study,
    );
    expect(week, hasLength(7));
    expect(week.first.date.weekday, DateTime.monday);
  });

  test('engine switches modes without binding renderer to demo data', () {
    final engine = TienMonPremiumEngine(
      scheduleAdapter: const TienMonDemoScheduleAdapter(),
      initialAnchor: DateTime(2026, 9, 29),
    );
    expect(engine.visibleWeek, hasLength(7));
    engine.setCalendarMode(TienMonCalendarMode.week);
    engine.navigate(1);
    expect(engine.anchor, DateTime(2026, 10, 6));
    engine.setScheduleMode(TienMonScheduleMode.exam);
    expect(engine.scheduleMode, TienMonScheduleMode.exam);
    engine.dispose();
  });

  test('known tofu glyphs are isolated onto unicode fallback', () {
    final spans = TienMonSafeText.spans('Tiết 1 • 3 — A2');
    final guarded = spans.where(
      (span) => TienMonSafeText.guardedGlyphs.contains(span.text),
    );
    expect(guarded, hasLength(2));
    expect(guarded.every((span) => span.style?.fontFamily == 'Roboto'), isTrue);
  });
}
