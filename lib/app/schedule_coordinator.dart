import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:flutter/foundation.dart';

/// In-memory schedule state before the offline repository is integrated.
class ScheduleCoordinator extends ChangeNotifier {
  List<ClassDto> classes = const <ClassDto>[];
  List<ExamDto> exams = const <ExamDto>[];
  String? error;
  bool loading = false;
  DateTime selectedDay = DateTime.now();

  void chooseDay(DateTime value) {
    selectedDay = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  void showPayload(QldtImportPayload payload) {
    classes = List<ClassDto>.unmodifiable(payload.classes);
    exams = List<ExamDto>.unmodifiable(payload.exams);
    error = null;
    notifyListeners();
  }

  void showError(Object problem) {
    error = problem.toString();
    notifyListeners();
  }
}

final ScheduleCoordinator scheduleCoordinator = ScheduleCoordinator();
