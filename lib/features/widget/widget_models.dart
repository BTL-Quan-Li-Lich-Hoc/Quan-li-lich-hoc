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

final class OverviewWidgetEntry {
  const OverviewWidgetEntry({
    required this.subjectName,
    required this.room,
    required this.startAt,
    required this.endAt,
  });

  factory OverviewWidgetEntry.fromClass(ClassDto value) {
    return OverviewWidgetEntry(
      subjectName: value.subjectName,
      room: value.room,
      startAt: value.startAt,
      endAt: value.endAt,
    );
  }

  final String subjectName;
  final String room;
  final DateTime startAt;
  final DateTime endAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'subjectName': subjectName,
      'room': room,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'time': '${_time(startAt)} - ${_time(endAt)}',
    };
  }
}

final class OverviewWidgetTimeline {
  OverviewWidgetTimeline(Iterable<OverviewWidgetEntry> entries)
    : entries = List<OverviewWidgetEntry>.unmodifiable(
        entries.toList()..sort(
          (OverviewWidgetEntry a, OverviewWidgetEntry b) =>
              a.startAt.compareTo(b.startAt),
        ),
      );

  final List<OverviewWidgetEntry> entries;

  String encode() {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final entry in entries) {
      grouped
          .putIfAbsent(_dateKey(entry.startAt), () => <Map<String, Object?>>[])
          .add(entry.toJson());
    }
    return jsonEncode(grouped);
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
