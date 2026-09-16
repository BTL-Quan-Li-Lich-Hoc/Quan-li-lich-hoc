import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class WidgetSettings {
  const WidgetSettings({
    this.showRoom = true,
    this.showTime = true,
    this.showDateControls = true,
    this.autoRefreshAfterSync = true,
  });

  final bool showRoom;
  final bool showTime;
  final bool showDateControls;
  final bool autoRefreshAfterSync;

  WidgetSettings copyWith({
    bool? showRoom,
    bool? showTime,
    bool? showDateControls,
    bool? autoRefreshAfterSync,
  }) {
    return WidgetSettings(
      showRoom: showRoom ?? this.showRoom,
      showTime: showTime ?? this.showTime,
      showDateControls: showDateControls ?? this.showDateControls,
      autoRefreshAfterSync: autoRefreshAfterSync ?? this.autoRefreshAfterSync,
    );
  }
}

final class WidgetSettingsStore {
  const WidgetSettingsStore();

  static const _showRoomKey = 'widget.showRoom';
  static const _showTimeKey = 'widget.showTime';
  static const _showDateControlsKey = 'widget.showDateControls';
  static const _autoRefreshAfterSyncKey = 'widget.autoRefreshAfterSync';

  Future<WidgetSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WidgetSettings(
      showRoom: prefs.getBool(_showRoomKey) ?? true,
      showTime: prefs.getBool(_showTimeKey) ?? true,
      showDateControls: prefs.getBool(_showDateControlsKey) ?? true,
      autoRefreshAfterSync: prefs.getBool(_autoRefreshAfterSyncKey) ?? true,
    );
  }

  Future<void> save(WidgetSettings value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showRoomKey, value.showRoom);
    await prefs.setBool(_showTimeKey, value.showTime);
    await prefs.setBool(_showDateControlsKey, value.showDateControls);
    await prefs.setBool(
      _autoRefreshAfterSyncKey,
      value.autoRefreshAfterSync,
    );
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_showRoomKey);
    await prefs.remove(_showTimeKey);
    await prefs.remove(_showDateControlsKey);
    await prefs.remove(_autoRefreshAfterSyncKey);
  }
}

final class WidgetSettingsController extends ChangeNotifier {
  WidgetSettingsController({WidgetSettingsStore? store})
    : _store = store ?? const WidgetSettingsStore();

  final WidgetSettingsStore _store;
  WidgetSettings _value = const WidgetSettings();
  bool _loading = false;

  WidgetSettings get value => _value;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _value = await _store.load();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> update(WidgetSettings value) async {
    _value = value;
    notifyListeners();
    await _store.save(value);
  }

  Future<void> reset() async {
    await _store.reset();
    _value = const WidgetSettings();
    notifyListeners();
  }
}
