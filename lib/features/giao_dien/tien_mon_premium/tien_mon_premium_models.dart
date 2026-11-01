import 'package:flutter/foundation.dart';

enum TienMonScheduleMode { study, exam }

enum TienMonCalendarMode { day, week }

enum TienMonSyncState { idle, loading, success, failure }

@immutable
class TienMonScheduleItem {
  const TienMonScheduleItem({
    required this.id,
    required this.subject,
    required this.room,
    required this.start,
    required this.end,
    required this.periods,
    this.isActive = false,
  });

  final String id;
  final String subject;
  final String room;
  final String start;
  final String end;
  final String periods;
  final bool isActive;
}

@immutable
class TienMonDaySchedule {
  const TienMonDaySchedule({required this.date, required this.items});

  final DateTime date;
  final List<TienMonScheduleItem> items;
}

abstract interface class TienMonScheduleAdapter {
  List<TienMonDaySchedule> loadWeek({
    required DateTime anchor,
    required TienMonScheduleMode mode,
  });
}

/// TIEN_MON_INTEGRATION: inject production schedule data here.
class TienMonDemoScheduleAdapter implements TienMonScheduleAdapter {
  const TienMonDemoScheduleAdapter();

  @override
  List<TienMonDaySchedule> loadWeek({
    required DateTime anchor,
    required TienMonScheduleMode mode,
  }) {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return List<TienMonDaySchedule>.generate(7, (day) {
      final date = DateTime(monday.year, monday.month, monday.day + day);
      if (mode == TienMonScheduleMode.exam) {
        return TienMonDaySchedule(
          date: date,
          items: day == 2
              ? const <TienMonScheduleItem>[
                  TienMonScheduleItem(
                    id: 'exam-ai',
                    subject: 'Trí tuệ nhân tạo',
                    room: 'A2-402',
                    start: '08:00',
                    end: '09:30',
                    periods: 'Ca thi 1',
                  ),
                ]
              : const <TienMonScheduleItem>[],
        );
      }
      const names = <String>[
        'Phân tích thiết kế hệ thống',
        'Lập trình ứng dụng di động',
        'An toàn thông tin',
        'Trí tuệ nhân tạo',
      ];
      if (day == 6) return TienMonDaySchedule(date: date, items: const []);
      final count = day.isEven ? 2 : 1;
      return TienMonDaySchedule(
        date: date,
        items: List<TienMonScheduleItem>.generate(
          count,
          (index) => TienMonScheduleItem(
            id: '$day-$index',
            subject: names[(day + index) % names.length],
            room: 'A${day + 1}-${301 + index}',
            start: index == 0 ? '07:00' : '13:00',
            end: index == 0 ? '09:30' : '15:30',
            periods: index == 0 ? 'Tiết 1 - 3' : 'Tiết 7 - 9',
            isActive: day == anchor.weekday - 1 && index == 0,
          ),
        ),
      );
    });
  }
}
