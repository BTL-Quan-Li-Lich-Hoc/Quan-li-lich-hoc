/// Stable, production-independent contract for the Tiên Môn Premium visual demo.
///
/// This file intentionally contains no QLĐT/database/theme-engine integration.
abstract final class TienMonPremiumContract {
  static const String themeKey = 'tien_mon_premium';
  static const String fontFamily = 'FzCoTrang';

  static const Duration sceneCrossfade = Duration(seconds: 3);
  static const Duration dayWeekTransition = Duration(milliseconds: 220);
  static const Duration calendarNavigationTransition = Duration(
    milliseconds: 240,
  );
  static const Duration studyExamTransition = Duration(milliseconds: 220);
  static const Duration notificationSheetTransition = Duration(
    milliseconds: 300,
  );
  static const Duration cardCascadeStagger = Duration(milliseconds: 50);
  static const Duration activeCardBreathingCycle = Duration(milliseconds: 6400);

  static const List<String> appSceneAssets = <String>[
    'assets/tien_mon_premium/app_backgrounds/tienmon_1_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_2_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_3_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_4_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_5_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_6_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_7_1440x2560.png',
    'assets/tien_mon_premium/app_backgrounds/tienmon_8_1440x2560.png',
  ];

  static const String widgetMorningAsset =
      'assets/tien_mon_premium/widget_overview/wid_sang.png';
  static const String widgetAfternoonAsset =
      'assets/tien_mon_premium/widget_overview/wid_chieu.png';
  static const String widgetNightAsset =
      'assets/tien_mon_premium/widget_overview/w_toi.png';

  /// Returns a 1-based scene id for local device time.
  static int appSceneFor(DateTime localTime) {
    final minutes = localTime.hour * 60 + localTime.minute;
    if (minutes >= 270 && minutes < 420) return 1; // 04:30-07:00
    if (minutes >= 420 && minutes < 600) return 2; // 07:00-10:00
    if (minutes >= 600 && minutes < 960) return 3; // 10:00-16:00
    if (minutes >= 960 && minutes < 1020) return 4; // 16:00-17:00
    if (minutes >= 1020 && minutes < 1110) return 5; // 17:00-18:30
    if (minutes >= 1110 && minutes < 1260) return 6; // 18:30-21:00
    if (minutes >= 1260 || minutes < 150) return 7; // 21:00-02:30
    return 8; // 02:30-04:30
  }

  /// Returns the next exact local boundary at which the app scene changes.
  ///
  /// The Premium background is intentionally event-driven instead of polling.
  /// Keeping this calculation in the contract makes the time rule testable and
  /// prevents renderer code from drifting away from [appSceneFor].
  static DateTime nextAppSceneBoundaryAfter(DateTime localTime) {
    const boundaries = <(int, int)>[
      (2, 30),
      (4, 30),
      (7, 0),
      (10, 0),
      (16, 0),
      (17, 0),
      (18, 30),
      (21, 0),
    ];

    DateTime at(int year, int month, int day, int hour, int minute) =>
        localTime.isUtc
        ? DateTime.utc(year, month, day, hour, minute)
        : DateTime(year, month, day, hour, minute);

    for (final boundary in boundaries) {
      final candidate = at(
        localTime.year,
        localTime.month,
        localTime.day,
        boundary.$1,
        boundary.$2,
      );
      if (candidate.isAfter(localTime)) return candidate;
    }

    final tomorrow = localTime.add(const Duration(days: 1));
    return at(tomorrow.year, tomorrow.month, tomorrow.day, 2, 30);
  }

  static TienMonOverviewWidgetScene widgetSceneFor(DateTime localTime) {
    final minutes = localTime.hour * 60 + localTime.minute;
    if (minutes >= 300 && minutes < 990) {
      return TienMonOverviewWidgetScene.morning; // 05:00-16:30
    }
    if (minutes >= 990 && minutes < 1110) {
      return TienMonOverviewWidgetScene.afternoon; // 16:30-18:30
    }
    return TienMonOverviewWidgetScene.night; // 18:30-05:00
  }
}

enum TienMonOverviewWidgetScene { morning, afternoon, night }
