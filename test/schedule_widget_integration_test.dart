import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_schedule_store.dart';
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

  test('loads the local cache and publishes both widget timelines', () async {
    final store = await LocalScheduleStore.open();
    final startAt = DateTime.now().add(const Duration(hours: 1));
    final selectedDay = DateTime(startAt.year, startAt.month, startAt.day);
    final classItem = ClassDto(
      id: 'class-1',
      subjectCode: 'MOB101',
      subjectName: 'Lập trình di động',
      room: 'A101',
      lecturer: 'Giảng viên',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 2)),
    );
    final examItem = ExamDto(
      id: 'exam-1',
      subjectCode: 'MOB101',
      subjectName: 'Lập trình di động',
      room: 'B202',
      startAt: startAt.add(const Duration(days: 7)),
      endAt: startAt.add(const Duration(days: 7, hours: 2)),
    );
    final payload = QldtImportPayload(
      user: const UserDto(
        studentId: 'test',
        displayName: 'Sinh viên thử nghiệm',
      ),
      semester: SemesterDto(
        id: '2026-1',
        name: 'Học kỳ 1',
        startDate: DateTime(startAt.year, 8),
        endDate: DateTime(startAt.year + 1, 1),
      ),
      classes: <ClassDto>[classItem],
      exams: <ExamDto>[examItem],
      syncedAt: DateTime.now(),
    );
    await store.replaceImport(payload);

    final bridge = _MemoryWidgetPlatformBridge();
    final widgetService = WidgetService(
      scheduleRepository: store,
      snapshotRepository: store,
      platformBridge: bridge,
    );
    final coordinator = ScheduleCoordinator(
      scheduleRepository: store,
      examRepository: store,
      initialDay: selectedDay,
    );
    coordinator.attachRepositories(
      onDataChanged: (day) async {
        await widgetService.refresh(selectedDate: day);
      },
    );

    await coordinator.load();

    expect(coordinator.status, ScheduleLoadStatus.ready);
    expect(coordinator.classes, <ClassDto>[classItem]);
    expect(coordinator.exams, <ExamDto>[examItem]);
    expect(
      bridge.timeline?.snapshotFor(selectedDay)?.subjectName,
      classItem.subjectName,
    );
    expect(bridge.overviewTimeline?.entries, hasLength(1));
    expect(bridge.settings, isNotNull);

    await store.dispose();
    coordinator.dispose();
  });
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
