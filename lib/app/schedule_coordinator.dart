import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:flutter/foundation.dart';

enum ScheduleLoadStatus { idle, loading, ready, empty, error }

typedef ScheduleDataChanged = Future<void> Function(DateTime selectedDay);

final class ScheduleCoordinator extends ChangeNotifier {
  ScheduleCoordinator({
    ScheduleRepository? scheduleRepository,
    ExamRepository? examRepository,
    QldtIntakeRepository? qldtRepository,
    DateTime? initialDay,
  }) : _scheduleRepository = scheduleRepository,
       _examRepository = examRepository,
       _qldtRepository = qldtRepository,
       selectedDay = _dateOnly(initialDay ?? DateTime.now());

  ScheduleRepository? _scheduleRepository;
  ExamRepository? _examRepository;
  QldtIntakeRepository? _qldtRepository;
  ScheduleDataChanged? _onDataChanged;
  int _operation = 0;

  List<ClassDto> classes = const <ClassDto>[];
  List<ExamDto> exams = const <ExamDto>[];
  ScheduleLoadStatus status = ScheduleLoadStatus.idle;
  String? error;
  DateTime selectedDay;

  bool get isLoading => status == ScheduleLoadStatus.loading;

  void attachRepositories({
    ScheduleRepository? scheduleRepository,
    ExamRepository? examRepository,
    QldtIntakeRepository? qldtRepository,
    ScheduleDataChanged? onDataChanged,
  }) {
    if (scheduleRepository != null) _scheduleRepository = scheduleRepository;
    if (examRepository != null) _examRepository = examRepository;
    if (qldtRepository != null) _qldtRepository = qldtRepository;
    if (onDataChanged != null) _onDataChanged = onDataChanged;
  }

  /// Reads only repository/cache data. It does not make a network request.
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

      if (operation != _operation) return;

      classes = List<ClassDto>.unmodifiable(nextClasses);
      exams = List<ExamDto>.unmodifiable(nextExams);
      status = classes.isEmpty && exams.isEmpty
          ? ScheduleLoadStatus.empty
          : ScheduleLoadStatus.ready;
      await _publishWidgetSnapshot();
    } on Object catch (problem) {
      if (operation != _operation) return;
      error = 'Không thể tải dữ liệu lịch: $problem';
      status = ScheduleLoadStatus.error;
    }

    notifyListeners();
  }

  /// QLĐT sync belongs to the app layer; native widgets never call it.
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
      if (operation != _operation) return;

      classes = List<ClassDto>.unmodifiable(payload.classes);
      exams = List<ExamDto>.unmodifiable(payload.exams);
      status = classes.isEmpty && exams.isEmpty
          ? ScheduleLoadStatus.empty
          : ScheduleLoadStatus.ready;
      await _publishWidgetSnapshot();
    } on Object catch (problem) {
      if (operation != _operation) return;
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

  Future<void> _publishWidgetSnapshot() async {
    final callback = _onDataChanged;
    if (callback == null) return;
    try {
      await callback(selectedDay);
    } on Object {
      // Keep the last widget snapshot; a widget failure must not hide the app data.
    }
  }
}

final ScheduleCoordinator scheduleCoordinator = ScheduleCoordinator();

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfWeek(DateTime value) {
  final day = _dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
