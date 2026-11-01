import 'dart:async';

import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_platform_bridge.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_service.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('starts empty until repositories are connected', () async {
    final coordinator = ScheduleCoordinator(initialDay: DateTime(2026, 10, 26));

    await coordinator.load();

    expect(coordinator.status, ScheduleLoadStatus.empty);
    expect(coordinator.classes, isEmpty);
    expect(coordinator.exams, isEmpty);
  });

  test('normalizes the selected date before reloading', () async {
    final coordinator = ScheduleCoordinator(initialDay: DateTime(2026, 10, 26));

    await coordinator.chooseDay(DateTime(2026, 10, 27, 19, 45));

    expect(coordinator.selectedDay, DateTime(2026, 10, 27));
  });

  test('accepts a payload that uses the shared contracts', () {
    final coordinator = ScheduleCoordinator();
    final classItem = ClassDto(
      id: 'class-1',
      subjectCode: 'MOB101',
      subjectName: 'Lập trình di động',
      room: 'A101',
      lecturer: 'Nguyễn Văn A',
      startAt: DateTime(2026, 10, 26, 8),
      endAt: DateTime(2026, 10, 26, 10),
    );
    final examItem = ExamDto(
      id: 'exam-1',
      subjectCode: 'MOB101',
      subjectName: 'Lập trình di động',
      room: 'B202',
      startAt: DateTime(2026, 11, 2, 13),
      endAt: DateTime(2026, 11, 2, 15),
    );
    final payload = QldtImportPayload(
      user: const UserDto(
        studentId: 'test',
        displayName: 'Sinh viên thử nghiệm',
      ),
      semester: SemesterDto(
        id: '2026-1',
        name: 'Học kỳ 1',
        startDate: DateTime(2026, 8),
        endDate: DateTime(2027),
      ),
      classes: <ClassDto>[classItem],
      exams: <ExamDto>[examItem],
      syncedAt: DateTime(2026, 10, 26),
    );

    coordinator.showPayload(payload);

    expect(coordinator.status, ScheduleLoadStatus.ready);
    expect(coordinator.classes, <ClassDto>[classItem]);
    expect(coordinator.exams, <ExamDto>[examItem]);
  });
  test('widget luôn lấy cả lịch hôm nay và ngày đang chọn', () async {
    final repository = _MemoryWidgetRepo();
    final service = WidgetService(
      scheduleRepository: repository,
      snapshotRepository: repository,
      platformBridge: _NoopWidgetBridge(),
    );
    final today = DateTime(2026, 11, 1, 10);
    final selected = DateTime(2027, 2, 2);
    await service.refresh(selectedDate: selected, now: today);

    expect(repository.lastFrom!.isBefore(today), isTrue);
    expect(repository.lastTo!.isAfter(selected), isTrue);
  });

}


class _MemoryWidgetRepo implements ScheduleRepository, WidgetSnapshotRepository {
  DateTime? lastFrom;
  DateTime? lastTo;
  WidgetSnapshot? snapshot;

  @override
  Stream<List<ClassDto>> watchRange({
    required DateTime from,
    required DateTime to,
  }) {
    lastFrom = from;
    lastTo = to;
    return Stream<List<ClassDto>>.value(<ClassDto>[]);
  }

  @override
  Future<void> replaceFromImport(QldtImportPayload payload) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<WidgetSnapshot?> read() async => snapshot;

  @override
  Future<void> write(WidgetSnapshot? value) async {
    snapshot = value;
  }

  @override
  Future<void> clear() async {
    snapshot = null;
  }
}

class _NoopWidgetBridge implements WidgetPlatformBridge {
  @override
  Future<void> publish({
    required WidgetTimeline timeline,
    required OverviewWidgetTimeline overviewTimeline,
    required WidgetSettings settings,
  }) async {}

  @override
  Future<void> clear() async {}
}
