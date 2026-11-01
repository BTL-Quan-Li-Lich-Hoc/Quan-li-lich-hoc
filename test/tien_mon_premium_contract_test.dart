import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 9, 29, hour, minute);

  group('Tiên Môn Premium app scene schedule', () {
    test('04:30-07:00 is scene 1', () {
      expect(TienMonPremiumContract.appSceneFor(at(4, 30)), 1);
      expect(TienMonPremiumContract.appSceneFor(at(6, 59)), 1);
    });
    test('07:00-10:00 is scene 2', () {
      expect(TienMonPremiumContract.appSceneFor(at(7, 0)), 2);
      expect(TienMonPremiumContract.appSceneFor(at(9, 59)), 2);
    });
    test('10:00-16:00 is scene 3', () {
      expect(TienMonPremiumContract.appSceneFor(at(10, 0)), 3);
      expect(TienMonPremiumContract.appSceneFor(at(15, 59)), 3);
    });
    test('16:00-17:00 is scene 4', () {
      expect(TienMonPremiumContract.appSceneFor(at(16, 0)), 4);
      expect(TienMonPremiumContract.appSceneFor(at(16, 59)), 4);
    });
    test('17:00-18:30 is scene 5', () {
      expect(TienMonPremiumContract.appSceneFor(at(17, 0)), 5);
      expect(TienMonPremiumContract.appSceneFor(at(18, 29)), 5);
    });
    test('18:30-21:00 is scene 6', () {
      expect(TienMonPremiumContract.appSceneFor(at(18, 30)), 6);
      expect(TienMonPremiumContract.appSceneFor(at(20, 59)), 6);
    });
    test('21:00-02:30 is scene 7 across midnight', () {
      expect(TienMonPremiumContract.appSceneFor(at(21, 0)), 7);
      expect(TienMonPremiumContract.appSceneFor(at(23, 59)), 7);
      expect(TienMonPremiumContract.appSceneFor(at(0, 0)), 7);
      expect(TienMonPremiumContract.appSceneFor(at(2, 29)), 7);
    });
    test('02:30-04:30 is scene 8', () {
      expect(TienMonPremiumContract.appSceneFor(at(2, 30)), 8);
      expect(TienMonPremiumContract.appSceneFor(at(4, 29)), 8);
    });
  });

  group('Tiên Môn Premium next scene boundary', () {
    test('uses the next exact boundary on the same day', () {
      expect(
        TienMonPremiumContract.nextAppSceneBoundaryAfter(at(6, 59)),
        at(7, 0),
      );
      expect(
        TienMonPremiumContract.nextAppSceneBoundaryAfter(at(18, 30)),
        at(21, 0),
      );
    });

    test('moves to 02:30 on the next day after 21:00', () {
      expect(
        TienMonPremiumContract.nextAppSceneBoundaryAfter(at(23, 59)),
        DateTime(2026, 9, 30, 2, 30),
      );
    });

    test('an exact boundary schedules the following boundary', () {
      expect(
        TienMonPremiumContract.nextAppSceneBoundaryAfter(at(7, 0)),
        at(10, 0),
      );
    });
  });

  group('Tiên Môn Premium overview widget schedule', () {
    test('morning starts at 05:00', () {
      expect(
        TienMonPremiumContract.widgetSceneFor(at(5, 0)),
        TienMonOverviewWidgetScene.morning,
      );
      expect(
        TienMonPremiumContract.widgetSceneFor(at(16, 29)),
        TienMonOverviewWidgetScene.morning,
      );
    });
    test('afternoon is 16:30-18:30', () {
      expect(
        TienMonPremiumContract.widgetSceneFor(at(16, 30)),
        TienMonOverviewWidgetScene.afternoon,
      );
      expect(
        TienMonPremiumContract.widgetSceneFor(at(18, 29)),
        TienMonOverviewWidgetScene.afternoon,
      );
    });
    test('night is 18:30-05:00 across midnight', () {
      expect(
        TienMonPremiumContract.widgetSceneFor(at(18, 30)),
        TienMonOverviewWidgetScene.night,
      );
      expect(
        TienMonPremiumContract.widgetSceneFor(at(4, 59)),
        TienMonOverviewWidgetScene.night,
      );
    });
  });
}
