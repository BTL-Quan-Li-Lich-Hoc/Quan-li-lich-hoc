import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_platform_bridge.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_settings.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_snapshot_selector.dart';

final class WidgetService {
  WidgetService({
    required ScheduleRepository scheduleRepository,
    required WidgetSnapshotRepository snapshotRepository,
    WidgetPlatformBridge? platformBridge,
    WidgetSettingsStore? settingsStore,
    WidgetSnapshotSelector? selector,
  }) : _scheduleRepository = scheduleRepository,
       _snapshotRepository = snapshotRepository,
       _platformBridge = platformBridge ?? const HomeWidgetPlatformBridge(),
       _settingsStore = settingsStore ?? const WidgetSettingsStore(),
       _selector = selector ?? const WidgetSnapshotSelector();

  static const _daysBefore = 14;
  static const _daysAfter = 60;

  final ScheduleRepository _scheduleRepository;
  final WidgetSnapshotRepository _snapshotRepository;
  final WidgetPlatformBridge _platformBridge;
  final WidgetSettingsStore _settingsStore;
  final WidgetSnapshotSelector _selector;

  Future<WidgetViewState> refresh({
    required DateTime selectedDate,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final selected = _dateOnly(selectedDate);
    final firstDay = selected.subtract(const Duration(days: _daysBefore));
    final lastDay = selected.add(const Duration(days: _daysAfter));
    final rangeEnd = lastDay.add(const Duration(days: 1));

    try {
      final classes = await _scheduleRepository
          .watchRange(from: firstDay, to: rangeEnd)
          .first;
      final timeline = _selector.buildTimeline(
        classes: classes,
        from: firstDay,
        through: lastDay,
        now: effectiveNow,
      );
      final selectedSnapshot = timeline.snapshotFor(selected);
      final settings = await _settingsStore.load();

      await _snapshotRepository.write(selectedSnapshot);
      await _platformBridge.publish(timeline: timeline, settings: settings);

      return WidgetViewState(
        status: selectedSnapshot == null
            ? WidgetStatus.empty
            : WidgetStatus.ready,
        selectedDate: selected,
        snapshot: selectedSnapshot,
        updatedAt: effectiveNow,
      );
    } on Object catch (error) {
      final staleSnapshot = await _readStaleSnapshot();
      return WidgetViewState(
        status: WidgetStatus.error,
        selectedDate: selected,
        snapshot: staleSnapshot,
        message: 'Không thể cập nhật widget: $error',
        updatedAt: effectiveNow,
      );
    }
  }

  Future<WidgetViewState> restore(DateTime selectedDate) async {
    final selected = _dateOnly(selectedDate);
    final snapshot = await _readStaleSnapshot();
    return WidgetViewState(
      status: snapshot == null ? WidgetStatus.empty : WidgetStatus.ready,
      selectedDate: selected,
      snapshot: snapshot,
    );
  }

  Future<void> refreshAfterSync() async {
    final settings = await _settingsStore.load();
    if (!settings.autoRefreshAfterSync) {
      return;
    }
    await refresh(selectedDate: DateTime.now());
  }

  Future<void> clear() async {
    await _snapshotRepository.clear();
    await _platformBridge.clear();
  }

  Future<WidgetSnapshot?> _readStaleSnapshot() async {
    try {
      return await _snapshotRepository.read();
    } on Object {
      return null;
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
