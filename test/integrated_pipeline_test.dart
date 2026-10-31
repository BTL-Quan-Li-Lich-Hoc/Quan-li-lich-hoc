import 'dart:convert';

import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_schedule_store.dart';
import 'package:better_phenikaa_schedule/features/timetable/domain/qldt_schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('parser -> persisted offline cache -> schedule/exam coordinator', () async {
    final raw = jsonEncode(<String, Object?>{
      'user': <String, String>{
        'studentId': 'test',
        'displayName': 'Sinh viên thử nghiệm',
      },
      'semester': <String, String>{
        'id': '2026-1',
        'name': 'Học kỳ 1',
        'startDate': '2026-09-01',
        'endDate': '2027-01-31',
      },
      'Data': <Map<String, String>>[
        <String, String>{
          'ID': 'study-1',
          'type': 'STUDY',
          'TENHOCPHAN': 'Lập trình di động',
          'startAt': '2026-10-26T08:00:00',
          'endAt': '2026-10-26T10:00:00',
          'PHONGHOC_TEN': 'A101',
        },
        <String, String>{
          'ID': 'exam-1',
          'type': 'EXAM',
          'TENHOCPHAN': 'Lập trình di động',
          'startAt': '2026-11-02T13:00:00',
          'endAt': '2026-11-02T15:00:00',
          'PHONGTHI': 'B202',
        },
      ],
    });
    final payload = QldtScheduleParser.parse(
      raw,
      receivedAt: DateTime(2026, 10, 26),
    );
    final store = await LocalScheduleStore.open();
    await store.replaceImport(payload);
    final offlineStore = await LocalScheduleStore.open();
    final coordinator = ScheduleCoordinator(
      initialDay: DateTime(2026, 10, 26),
    );
    coordinator.attachRepositories(
      scheduleRepository: offlineStore,
      examRepository: offlineStore,
    );
    await coordinator.load();
    expect(coordinator.status, ScheduleLoadStatus.ready);
    expect(coordinator.classes.single.subjectName, 'Lập trình di động');
    expect(coordinator.exams.single.room, 'B202');
    await store.dispose();
    await offlineStore.dispose();
    coordinator.dispose();
  });
}
