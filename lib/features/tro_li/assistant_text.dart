import 'package:better_phenikaa_schedule/features/tro_li/assistant_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AssistantPack {
  normal('Bình thường'),
  serious('Nghiêm túc'),
  playful('Nhí nhảnh'),
  affectionate('Tình cảm'),
  flirtatious('Mập mờ'),
  academic('Học thuật'),
  blunt('Mỏ hỗn'),
  cultivation('Tu Tiên');

  new(this.label);
  final String label;
}

enum AssistantEvent {
  syncInitial,
  notificationEmpty,
  notificationEmptyDescription,
  syncStale,
  syncSuccessNoChange,
  studyChanged,
  examChanged,
  studyAndExamChanged,
  examInDays,
  examTomorrow,
  examPeriodActive,
  examCountdownMultiple,
  widgetSyncChanged,
  widgetSyncUnchanged,
  differenceUnread,
  examEmpty,
  studyTodayEmpty,
  syncFailed,
  syncTimeout,
}

/// One pack governs all in-app messages and Android notifications.
abstract final class AssistantSelection {
  static const storageKey = 'better_phenikaa_assistant_pack_v1';

  static Future<AssistantPack> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AssistantPack.values.firstWhere(
      (pack) => pack.name == prefs.getString(storageKey),
      orElse: () => AssistantPack.normal,
    );
  }

  static Future<void> save(AssistantPack pack) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, pack.name);
  }
}

abstract final class AssistantText {
  static String titleOf(AssistantEvent event, AssistantPack pack) =>
      switch (event) {
        AssistantEvent.notificationEmpty => 'Thông báo',
        AssistantEvent.notificationEmptyDescription => 'Thông báo',
        AssistantEvent.syncStale => 'Nhắc đồng bộ',
        AssistantEvent.syncInitial ||
        AssistantEvent.syncSuccessNoChange ||
        AssistantEvent.studyChanged ||
        AssistantEvent.examChanged ||
        AssistantEvent.studyAndExamChanged ||
        AssistantEvent.widgetSyncChanged ||
        AssistantEvent.widgetSyncUnchanged ||
        AssistantEvent.syncFailed ||
        AssistantEvent.syncTimeout => 'Đồng bộ QLĐT',
        AssistantEvent.examInDays ||
        AssistantEvent.examTomorrow ||
        AssistantEvent.examCountdownMultiple ||
        AssistantEvent.examPeriodActive ||
        AssistantEvent.examEmpty => 'Lịch thi',
        AssistantEvent.differenceUnread => 'Thông báo',
        AssistantEvent.studyTodayEmpty => 'Lịch học',
      };

  static String of(
    AssistantEvent event,
    AssistantPack pack, {
    int days = 0,
    int examCount = 1,
    bool inWidget = false,
    Map<String, Map<int, String>>? templates,
  }) {
    final useCase = switch (event) {
      AssistantEvent.syncStale => 1,
      AssistantEvent.syncSuccessNoChange => 2,
      AssistantEvent.studyChanged => 3,
      AssistantEvent.examChanged => 4,
      AssistantEvent.studyAndExamChanged => 5,
      AssistantEvent.examInDays when examCount > 1 => 11,
      AssistantEvent.examInDays when days == 7 => 6,
      AssistantEvent.examInDays when days == 3 => 7,
      AssistantEvent.examInDays => 9,
      AssistantEvent.examTomorrow when examCount > 1 => 11,
      AssistantEvent.examTomorrow => 8,
      AssistantEvent.examPeriodActive => 10,
      AssistantEvent.examCountdownMultiple => 11,
      AssistantEvent.widgetSyncChanged => 12,
      AssistantEvent.widgetSyncUnchanged => 13,
      AssistantEvent.differenceUnread => 14,
      AssistantEvent.examEmpty => 15,
      AssistantEvent.studyTodayEmpty => 16,
      AssistantEvent.syncFailed => 17,
      AssistantEvent.syncTimeout => 18,
      AssistantEvent.syncInitial ||
      AssistantEvent.notificationEmpty ||
      AssistantEvent.notificationEmptyDescription => null,
    };
    if (useCase == null) {
      return switch (event) {
        AssistantEvent.syncInitial => 'Đã lưu dữ liệu học kỳ đầu tiên.',
        AssistantEvent.notificationEmpty => 'Không có thông báo mới.',
        _ => 'Các thông báo mới sẽ xuất hiện ở đây.',
      };
    }
    final catalog = templates ?? assistantCatalog;
    final template =
        catalog[pack.name]?[useCase] ??
        catalog[AssistantPack.normal.name]![useCase]!;
    final resolved = switch (useCase) {
      9 => template.replaceFirst('X', '$days'),
      11 => template.replaceFirst('X', '$days').replaceFirst('N', '$examCount'),
      _ => template,
    };
    return inWidget && pack == AssistantPack.flirtatious
        ? resolved.replaceAll('❤️', '<3')
        : resolved;
  }
}
