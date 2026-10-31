import 'package:flutter/foundation.dart';

import 'background/tien_mon_background.dart';
import 'tien_mon_premium_models.dart';

/// Production-independent state boundary shared by the Premium renderers.
///
/// DemoF3 data/actions are intentionally consumed only through [scheduleAdapter].
class TienMonPremiumEngine extends ChangeNotifier {
  TienMonPremiumEngine({
    required this.scheduleAdapter,
    TienMonSceneController? sceneController,
    DateTime? initialAnchor,
  }) : scenes = sceneController ?? TienMonSceneController(),
       _anchor = initialAnchor ?? DateTime.now() {
    scenes.addListener(_forwardSceneChange);
  }

  final TienMonScheduleAdapter scheduleAdapter;
  final TienMonSceneController scenes;

  DateTime _anchor;
  TienMonCalendarMode _calendarMode = TienMonCalendarMode.day;
  TienMonScheduleMode _scheduleMode = TienMonScheduleMode.study;
  TienMonSyncState _syncState = TienMonSyncState.idle;

  DateTime get anchor => _anchor;
  TienMonCalendarMode get calendarMode => _calendarMode;
  TienMonScheduleMode get scheduleMode => _scheduleMode;
  TienMonSyncState get syncState => _syncState;

  List<TienMonDaySchedule> get visibleWeek =>
      scheduleAdapter.loadWeek(anchor: _anchor, mode: _scheduleMode);

  void setCalendarMode(TienMonCalendarMode value) {
    if (_calendarMode == value) return;
    _calendarMode = value;
    notifyListeners();
  }

  void setScheduleMode(TienMonScheduleMode value) {
    if (_scheduleMode == value) return;
    _scheduleMode = value;
    notifyListeners();
  }

  void navigate(int direction) {
    final step = _calendarMode == TienMonCalendarMode.day ? 1 : 7;
    _anchor = _anchor.add(Duration(days: direction.sign * step));
    notifyListeners();
  }

  void setSyncState(TienMonSyncState value) {
    if (_syncState == value) return;
    _syncState = value;
    notifyListeners();
  }

  void _forwardSceneChange() => notifyListeners();

  @override
  void dispose() {
    scenes.removeListener(_forwardSceneChange);
    scenes.dispose();
    super.dispose();
  }
}
