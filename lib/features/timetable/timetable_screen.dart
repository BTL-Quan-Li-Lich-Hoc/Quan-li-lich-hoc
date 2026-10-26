import 'dart:async';

import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/app/schedule_formatters.dart';
import 'package:better_phenikaa_schedule/app/schedule_state_panel.dart';
import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:flutter/material.dart';

enum TimetableViewMode { day, week }

class TimetableScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  TimetableViewMode _mode = TimetableViewMode.day;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scheduleCoordinator,
      builder: (context, child) {
        final coordinator = scheduleCoordinator;
        final visibleClasses = _classesForView(coordinator);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lịch học'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Tải lại lịch',
                onPressed: () => unawaited(coordinator.load()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<TimetableViewMode>(
                  segments: const <ButtonSegment<TimetableViewMode>>[
                    ButtonSegment<TimetableViewMode>(
                      value: TimetableViewMode.day,
                      label: Text('Ngày'),
                      icon: Icon(Icons.today_outlined),
                    ),
                    ButtonSegment<TimetableViewMode>(
                      value: TimetableViewMode.week,
                      label: Text('Tuần'),
                      icon: Icon(Icons.calendar_view_week_outlined),
                    ),
                  ],
                  selected: <TimetableViewMode>{_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              ),
              _buildDateNavigator(coordinator),
              Expanded(child: _buildContent(coordinator, visibleClasses)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateNavigator(ScheduleCoordinator coordinator) {
    final dayDelta = _mode == TimetableViewMode.day ? 1 : 7;
    final dateLabel = _mode == TimetableViewMode.day
        ? formatScheduleDay(coordinator.selectedDay)
        : formatScheduleWeek(coordinator.selectedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Khoảng thời gian trước',
                onPressed: () => unawaited(
                  coordinator.chooseDay(
                    coordinator.selectedDay.subtract(Duration(days: dayDelta)),
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Khoảng thời gian sau',
                onPressed: () => unawaited(
                  coordinator.chooseDay(
                    coordinator.selectedDay.add(Duration(days: dayDelta)),
                  ),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => unawaited(coordinator.chooseDay(DateTime.now())),
              child: const Text('Hôm nay'),
            ),
          ),
        ],
      ),
    );
  }

  List<ClassDto> _classesForView(ScheduleCoordinator coordinator) {
    final dayStart = DateTime(
      coordinator.selectedDay.year,
      coordinator.selectedDay.month,
      coordinator.selectedDay.day,
    );
    final rangeStart = _mode == TimetableViewMode.day
        ? dayStart
        : startOfScheduleWeek(dayStart);
    final rangeEnd = rangeStart.add(
      Duration(days: _mode == TimetableViewMode.day ? 1 : 7),
    );
    final result =
        coordinator.classes
            .where(
              (item) =>
                  item.startAt.isBefore(rangeEnd) &&
                  item.endAt.isAfter(rangeStart),
            )
            .toList()
          ..sort((first, second) => first.startAt.compareTo(second.startAt));
    return result;
  }

  Widget _buildContent(
    ScheduleCoordinator coordinator,
    List<ClassDto> visibleClasses,
  ) {
    if (coordinator.status == ScheduleLoadStatus.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải lịch học…'),
          ],
        ),
      );
    }

    if (coordinator.status == ScheduleLoadStatus.error) {
      return ScheduleStatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Không tải được lịch học',
        message: coordinator.error ?? 'Đã xảy ra lỗi không xác định.',
        actionLabel: 'Thử lại',
        onAction: () => unawaited(coordinator.load()),
      );
    }

    if (visibleClasses.isEmpty) {
      return ScheduleStatePanel(
        icon: Icons.event_busy_outlined,
        title: 'Chưa có lịch học',
        message: _mode == TimetableViewMode.day
            ? 'Không có buổi học trong ngày đã chọn.'
            : 'Không có buổi học trong tuần đã chọn.',
        actionLabel: 'Tải lại',
        onAction: () => unawaited(coordinator.load()),
      );
    }

    if (_mode == TimetableViewMode.day) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: visibleClasses.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) => _classCard(visibleClasses[index]),
      );
    }

    return _buildWeekList(coordinator, visibleClasses);
  }

  Widget _buildWeekList(
    ScheduleCoordinator coordinator,
    List<ClassDto> visibleClasses,
  ) {
    final weekStart = startOfScheduleWeek(coordinator.selectedDay);
    final children = <Widget>[];

    for (var offset = 0; offset < 7; offset++) {
      final day = weekStart.add(Duration(days: offset));
      final dailyClasses =
          visibleClasses
              .where((item) => isSameScheduleDay(item.startAt, day))
              .toList()
            ..sort((first, second) => first.startAt.compareTo(second.startAt));

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            formatScheduleDay(day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );

      if (dailyClasses.isEmpty) {
        children.add(
          const ListTile(
            dense: true,
            leading: Icon(Icons.remove_circle_outline),
            title: Text('Không có lớp'),
          ),
        );
      } else {
        children.addAll(dailyClasses.map(_classCard));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: children,
    );
  }

  Widget _classCard(ClassDto item) {
    final room = item.room.isEmpty ? 'Chưa có phòng' : item.room;
    final lecturer = item.lecturer.isEmpty
        ? 'Chưa có thông tin giảng viên'
        : item.lecturer;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
        title: Text(item.subjectName),
        subtitle: Text('${item.subjectCode} • $room\n$lecturer'),
        isThreeLine: true,
        trailing: Text(
          formatScheduleTimeRange(item.startAt, item.endAt),
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}
