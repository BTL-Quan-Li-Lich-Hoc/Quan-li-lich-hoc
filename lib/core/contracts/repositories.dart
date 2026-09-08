import 'package:better_phenikaa_schedule/core/contracts/models.dart';

abstract interface class QldtIntakeRepository {
  Future<bool> hasValidSession();

  Future<QldtImportPayload> sync();

  Future<void> clearSession();
}

abstract interface class ScheduleRepository {
  Stream<List<ClassDto>> watchRange({
    required DateTime from,
    required DateTime to,
  });

  Future<void> replaceFromImport(QldtImportPayload payload);

  Future<void> clearAll();
}

abstract interface class ExamRepository {
  Stream<List<ExamDto>> watchAll();

  Future<void> replaceFromImport(QldtImportPayload payload);

  Future<void> clearAll();
}

abstract interface class WidgetSnapshotRepository {
  Future<WidgetSnapshot?> read();

  Future<void> write(WidgetSnapshot? snapshot);

  Future<void> clear();
}
