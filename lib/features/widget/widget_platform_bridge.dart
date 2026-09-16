import 'package:better_phenikaa_schedule/features/widget/widget_models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

abstract interface class WidgetPlatformBridge {
  Future<void> publish({
    required WidgetTimeline timeline,
    required WidgetSettings settings,
  });

  Future<void> clear();
}

final class HomeWidgetPlatformBridge implements WidgetPlatformBridge {
  const HomeWidgetPlatformBridge({
    this.androidProviderName = 'ScheduleWidgetProvider',
  });

  final String androidProviderName;

  static const _timelineKey = 'widgetTimeline';
  static const _showRoomKey = 'showRoom';
  static const _showTimeKey = 'showTime';
  static const _showDateControlsKey = 'showDateControls';

  bool get _supportsHomeWidget {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Future<void> publish({
    required WidgetTimeline timeline,
    required WidgetSettings settings,
  }) async {
    if (!_supportsHomeWidget) {
      return;
    }

    await HomeWidget.saveWidgetData<String>(_timelineKey, timeline.encode());
    await HomeWidget.saveWidgetData<bool>(_showRoomKey, settings.showRoom);
    await HomeWidget.saveWidgetData<bool>(_showTimeKey, settings.showTime);
    await HomeWidget.saveWidgetData<bool>(
      _showDateControlsKey,
      settings.showDateControls,
    );
    await _requestUpdate();
  }

  @override
  Future<void> clear() async {
    if (!_supportsHomeWidget) {
      return;
    }

    await HomeWidget.saveWidgetData<String>(_timelineKey, '{}');
    await _requestUpdate();
  }

  Future<void> _requestUpdate() {
    return HomeWidget.updateWidget(
      name: androidProviderName,
      androidName: androidProviderName,
    );
  }
}
