import 'dart:async';

import 'package:better_phenikaa_schedule/app/schedule_coordinator.dart';
import 'package:better_phenikaa_schedule/app/schedule_formatters.dart';
import 'package:better_phenikaa_schedule/app/schedule_state_panel.dart';
import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:flutter/material.dart';

class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scheduleCoordinator,
      builder: (context, child) {
        final coordinator = scheduleCoordinator;
        final exams = coordinator.exams.toList()
          ..sort((first, second) => first.startAt.compareTo(second.startAt));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lịch thi'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Tải lại lịch thi',
                onPressed: () => unawaited(coordinator.load()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildContent(coordinator, exams),
        );
      },
    );
  }

  Widget _buildContent(ScheduleCoordinator coordinator, List<ExamDto> exams) {
    if (coordinator.status == ScheduleLoadStatus.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải lịch thi…'),
          ],
        ),
      );
    }

    if (coordinator.status == ScheduleLoadStatus.error) {
      return ScheduleStatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Không tải được lịch thi',
        message: coordinator.error ?? 'Đã xảy ra lỗi không xác định.',
        actionLabel: 'Thử lại',
        onAction: () => unawaited(coordinator.load()),
      );
    }

    if (exams.isEmpty) {
      return ScheduleStatePanel(
        icon: Icons.assignment_late_outlined,
        title: 'Chưa có lịch thi',
        message: 'Lịch thi sẽ xuất hiện tại đây sau khi có dữ liệu.',
        actionLabel: 'Tải lại',
        onAction: () => unawaited(coordinator.load()),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: exams.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final exam = exams[index];
        final room = exam.room.isEmpty ? 'Chưa có phòng' : exam.room;
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
            title: Text(exam.subjectName),
            subtitle: Text(
              '${exam.subjectCode} • ${formatScheduleDay(exam.startAt)}\n$room',
            ),
            isThreeLine: true,
            trailing: Text(
              formatScheduleTimeRange(exam.startAt, exam.endAt),
              textAlign: TextAlign.end,
            ),
          ),
        );
      },
    );
  }
}
