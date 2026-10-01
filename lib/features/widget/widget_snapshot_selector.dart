import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/features/widget/widget_models.dart';

final class WidgetSnapshotSelector {
  const WidgetSnapshotSelector();

  WidgetSnapshot? selectForDate({
    required Iterable<ClassDto> classes,
    required DateTime selectedDate,
    required DateTime now,
  }) {
    final dayStart = _dateOnly(selectedDate);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final candidates = classes
        .where(
          (item) =>
              item.startAt.isBefore(dayEnd) && item.endAt.isAfter(dayStart),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (candidates.isEmpty) {
      return null;
    }

    ClassDto? selected;
    if (_sameDay(dayStart, now)) {
      for (final item in candidates) {
        final isCurrent =
            !item.startAt.isAfter(now) && item.endAt.isAfter(now);
        if (isCurrent) {
          selected = item;
          break;
        }
      }
      selected ??= _firstUpcoming(candidates, now);
    } else {
      selected = candidates.first;
    }

    if (selected == null) {
      return null;
    }

    return WidgetSnapshot(
      subjectName: selected.subjectName,
      room: selected.room,
      startAt: selected.startAt,
      endAt: selected.endAt,
    );
  }

  WidgetTimeline buildTimeline({
    required Iterable<ClassDto> classes,
    required DateTime from,
    required DateTime through,
    required DateTime now,
  }) {
    final entries = <WidgetTimelineEntry>[];
    var cursor = _dateOnly(from);
    final lastDay = _dateOnly(through);

    while (!cursor.isAfter(lastDay)) {
      final snapshot = selectForDate(
        classes: classes,
        selectedDate: cursor,
        now: now,
      );
      if (snapshot != null) {
        entries.add(WidgetTimelineEntry(date: cursor, snapshot: snapshot));
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return WidgetTimeline(entries);
  }

  ClassDto? _firstUpcoming(List<ClassDto> classes, DateTime now) {
    for (final item in classes) {
      if (!item.startAt.isBefore(now)) {
        return item;
      }
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
