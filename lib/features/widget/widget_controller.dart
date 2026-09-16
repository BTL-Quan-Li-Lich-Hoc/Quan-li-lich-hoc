import 'package:better_phenikaa_schedule/features/widget/widget_models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_service.dart';
import 'package:flutter/foundation.dart';

final class WidgetController extends ChangeNotifier {
  WidgetController({required WidgetService service, DateTime? initialDate})
    : _service = service,
      _state = WidgetViewState.initial(initialDate ?? DateTime.now());

  final WidgetService _service;
  WidgetViewState _state;
  int _operation = 0;

  WidgetViewState get state => _state;

  Future<void> initialize() async {
    final cached = await _service.restore(_state.selectedDate);
    _state = cached;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final operation = ++_operation;
    _state = WidgetViewState(
      status: WidgetStatus.loading,
      selectedDate: _state.selectedDate,
      snapshot: _state.snapshot,
      updatedAt: _state.updatedAt,
    );
    notifyListeners();

    final next = await _service.refresh(selectedDate: _state.selectedDate);
    if (operation != _operation) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    _state = WidgetViewState(
      status: WidgetStatus.loading,
      selectedDate: _dateOnly(date),
      snapshot: _state.snapshot,
      updatedAt: _state.updatedAt,
    );
    notifyListeners();
    await refresh();
  }

  Future<void> previousDay() {
    return selectDate(_state.selectedDate.subtract(const Duration(days: 1)));
  }

  Future<void> nextDay() {
    return selectDate(_state.selectedDate.add(const Duration(days: 1)));
  }

  Future<void> today() {
    return selectDate(DateTime.now());
  }

  Future<void> clear() async {
    ++_operation;
    await _service.clear();
    _state = WidgetViewState(
      status: WidgetStatus.empty,
      selectedDate: _state.selectedDate,
    );
    notifyListeners();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
