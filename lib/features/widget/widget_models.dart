import 'dart:convert';

import 'package:better_phenikaa_schedule/core/contracts/models.dart';

enum WidgetStatus { idle, loading, ready, empty, error }

final class WidgetViewState {
  const WidgetViewState({
    required this.status,
    required this.selectedDate,
    this.snapshot,
    this.message,
    this.updatedAt,
  });

  factory WidgetViewState.initial(DateTime selectedDate) {
    return WidgetViewState(
      status: WidgetStatus.idle,
      selectedDate: _dateOnly(selectedDate),
    );
  }

  final WidgetStatus status;
  final DateTime selectedDate;
  final WidgetSnapshot? snapshot;
  final String? message;
  final DateTime? updatedAt;

  bool get hasData => snapshot != null;
}

final class WidgetTimelineEntry {
  const WidgetTimelineEntry({required this.date, required this.snapshot});

  final DateTime date;
  final WidgetSnapshot snapshot;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'subjectName': snapshot.subjectName,
      'room': snapshot.room,
      'startAt': snapshot.startAt.toIso8601String(),
      'endAt': snapshot.endAt.toIso8601String(),
      'time': '${_time(snapshot.startAt)} - ${_time(snapshot.endAt)}',
    };
  }
}

final class WidgetTimeline {
  WidgetTimeline(Iterable<WidgetTimelineEntry> entries)
    : entries = List<WidgetTimelineEntry>.unmodifiable(entries);

  final List<WidgetTimelineEntry> entries;

  bool get isEmpty => entries.isEmpty;

  WidgetSnapshot? snapshotFor(DateTime date) {
    final key = _dateKey(date);
    for (final entry in entries) {
      if (_dateKey(entry.date) == key) {
        return entry.snapshot;
      }
    }
    return null;
  }

  String encode() {
    final payload = <String, Object?>{
      for (final entry in entries) _dateKey(entry.date): entry.toJson(),
    };
    return jsonEncode(payload);
  }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
