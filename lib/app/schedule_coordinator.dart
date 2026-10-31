import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:flutter/foundation.dart';

enum ScheduleLoadStatus { idle, loading, ready, empty, error }

/// Coordinates schedule and exam data shared by the Flutter screens.
final class ScheduleCoordinator extends ChangeNotifier {
  ScheduleCoordinator({
    this._scheduleRepository,
    this._examRepository,
    this._qldtRepository,
    DateTime? initialDay,
  }) : selectedDay = _dateOnly(initialDay ?? DateTime.now());

  ScheduleRepository? _scheduleRepository;
  ExamRepository? _examRepository;
  QldtIntakeRepository? _qldtRepository;
  int _operation = 0;

  List<ClassDto> classes = const <ClassDto>[];
  List<ExamDto> exams = const <ExamDto>[];
  ScheduleLoadStatus status = ScheduleLoadStatus.idle;
  String? error;
  DateTime selectedDay;

  bool get isLoading => status == ScheduleLoadStatus.loading;

  /// Connects repositories when the corresponding data modules are ready.
  void attachRepositories({
    ScheduleRepository? scheduleRepository,
    ExamRepository? examRepository,
    QldtIntakeRepository? qldtRepository,
  }) {
    if (scheduleRepository != null) {
      _scheduleRepository = scheduleRepository;
    }
    if (examRepository != null) {
      _examRepository = examRepository;
    }
    if (qldtRepository != null) {
      _qldtRepository = qldtRepository;
    }
  }

  /// Loads the selected week and the current exam list through the contracts.
  Future<void> load() async {
    final scheduleRepository = _scheduleRepository;
    final examRepository = _examRepository;

    if (scheduleRepository == null && examRepository == null) {
      error = null;
      status = classes.isEmpty && exams.isEmpty
          ? ScheduleLoadStatus.empty
          : ScheduleLoadStatus.ready;
      notifyListeners();
      return;
    }

    final operation = ++_operation;
    status = ScheduleLoadStatus.loading;
    error = null;
    notifyListeners();

    try {
      final weekStart = _startOfWeek(selectedDay);
      final weekEnd = weekStart.add(const Duration(days: 7));
      final nextClasses = scheduleRepository == null
          ? classes
          : await scheduleRepository
                .watchRange(from: weekStart, to: weekEnd)
                .first;
      final nextExams = examRepository == null
          ? exams
          : await examRepository.watchAll().first;

      if (operation != _operation) {
        return;
      }

      classes = List<ClassDto>.unmodifiable(nextClasses);
      exams = List<ExamDto>.unmodifiable(nextExams);
      status = classes.isEmpty && exams.isEmpty
          ? ScheduleLoadStatus.empty
          : ScheduleLoadStatus.ready;
    } on Object catch (problem) {
      if (operation != _operation) {
        return;
      }
      error = 'Không thể tải dữ liệu lịch: $problem';
      status = ScheduleLoadStatus.error;
    }

    notifyListeners();
  }

  /// Synchronizes through QLĐT, persists via repositories, then refreshes UI.
  Future<void> syncFromQldt() async {
    final qldtRepository = _qldtRepository;
    final scheduleRepository = _scheduleRepository;
    final examRepository = _examRepository;

    if (qldtRepository == null ||
        scheduleRepository == null ||
        examRepository == null) {
      showError(
        StateError('Chưa kết nối đủ repository QLĐT, lịch học và lịch thi.'),
      );
      return;
    }

    final operation = ++_operation;
    status = ScheduleLoadStatus.loading;
    error = null;
    notifyListeners();

    try {
      final payload = await qldtRepository.sync();
      await scheduleRepository.replaceFromImport(payload);
      await examRepository.replaceFromImport(payload);

      if (operation != _operation) {
        return;
      }

      classes = List<ClassDto>.unmodifiable(payload.classes);
      exams = List<ExamDto>.unmodifiable(payload.exams);
      status = classes.isEmpty && exams.isEmpty
          ? ScheduleLoadStatus.empty
          : ScheduleLoadStatus.ready;
    } on Object catch (problem) {
      if (operation != _operation) {
        return;
      }
      error = 'Đồng bộ QLĐT thất bại: $problem';
      status = ScheduleLoadStatus.error;
    }

    notifyListeners();
  }

  Future<void> chooseDay(DateTime value) async {
    selectedDay = _dateOnly(value);
    notifyListeners();
    await load();
  }

  void showPayload(QldtImportPayload payload) {
    ++_operation;
    classes = List<ClassDto>.unmodifiable(payload.classes);
    exams = List<ExamDto>.unmodifiable(payload.exams);
    error = null;
    status = classes.isEmpty && exams.isEmpty
        ? ScheduleLoadStatus.empty
        : ScheduleLoadStatus.ready;
    notifyListeners();
  }

  void showError(Object problem) {
    ++_operation;
    error = problem.toString();
    status = ScheduleLoadStatus.error;
    notifyListeners();
  }
}

final ScheduleCoordinator scheduleCoordinator = ScheduleCoordinator();

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfWeek(DateTime value) {
  final day = _dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
