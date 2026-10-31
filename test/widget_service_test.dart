import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_platform_bridge.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_service.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('keeps today and the selected day in the published timeline', () async {
    final now = DateTime(2026, 10, 31, 9);
    final selected = DateTime(2026, 12, 15);
    final todayClass = _class('today', DateTime(2026, 10, 31, 8));
    final selectedClass = _class('selected', DateTime(2026, 12, 15, 8));
    final repository = _MemoryScheduleRepository(
      <ClassDto>[todayClass, selectedClass],
    );
    final snapshots = _MemorySnapshotRepository();
    final bridge = _MemoryWidgetPlatformBridge();
    final service = WidgetService(
      scheduleRepository: repository,
      snapshotRepository: snapshots,
      platformBridge: bridge,
    );

    await service.refresh(selectedDate: selected, now: now);

    expect(
      bridge.timeline?.snapshotFor(now)?.subjectName,
      'today',
    );
    expect(
      bridge.timeline?.snapshotFor(selected)?.subjectName,
      'selected',
    );
    expect(snapshots.value?.subjectName, 'selected');
    expect(repository.requestedFrom, DateTime(2026, 10, 17));
  });
}

ClassDto _class(String name, DateTime startAt) {
  return ClassDto(
    id: name,
    subjectCode: name,
    subjectName: name,
    room: 'A101',
    lecturer: '',
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 2)),
  );
}

class _MemoryScheduleRepository implements ScheduleRepository {
  _MemoryScheduleRepository(this.classes);

  final List<ClassDto> classes;
  DateTime? requestedFrom;
  DateTime? requestedTo;

  @override
  Stream<List<ClassDto>> watchRange({
    required DateTime from,
    required DateTime to,
  }) {
    requestedFrom = from;
    requestedTo = to;
    return Stream<List<ClassDto>>.value(classes);
  }

  @override
  Future<void> replaceFromImport(QldtImportPayload payload) async {}

  @override
  Future<void> clearAll() async {}
}

class _MemorySnapshotRepository implements WidgetSnapshotRepository {
  WidgetSnapshot? value;

  @override
  Future<WidgetSnapshot?> read() async => value;

  @override
  Future<void> write(WidgetSnapshot? snapshot) async {
    value = snapshot;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _MemoryWidgetPlatformBridge implements WidgetPlatformBridge {
  WidgetTimeline? timeline;
  OverviewWidgetTimeline? overviewTimeline;
  WidgetSettings? settings;

  @override
  Future<void> publish({
    required WidgetTimeline timeline,
    required OverviewWidgetTimeline overviewTimeline,
    required WidgetSettings settings,
  }) async {
    this.timeline = timeline;
    this.overviewTimeline = overviewTimeline;
    this.settings = settings;
  }

  @override
  Future<void> clear() async {}
}
