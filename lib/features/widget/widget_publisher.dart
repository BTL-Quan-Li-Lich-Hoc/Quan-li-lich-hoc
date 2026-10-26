import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:home_widget/home_widget.dart';

/// Publishes the cached daily schedule; widgets never contact QLDT.
class ScheduleWidgetPublisher {
  static Future<void> publish(List<ClassDto> classes) async {
    final now = DateTime.now();
    final todays = classes.where((entry) {
      final day = entry.startAt;
      return day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;
    }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));

    final next = todays.isEmpty ? null : todays.first;
    final time = next?.startAt;
    final startTime = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';

    await HomeWidget.saveWidgetData<String>(
      'btl_small_title',
      next?.subjectName ?? 'Không có lịch học hôm nay',
    );
    await HomeWidget.saveWidgetData<String>(
      'btl_small_body',
      next == null
          ? 'Mở ứng dụng để kiểm tra lịch'
          : '${next.room} • $startTime',
    );
    await HomeWidget.saveWidgetData<String>(
      'btl_large_title',
      'Lịch học hôm nay (${todays.length})',
    );
    await HomeWidget.saveWidgetData<String>(
      'btl_large_body',
      todays.isEmpty
          ? 'Không có buổi học'
          : todays
                .take(5)
                .map((entry) {
                  final time = entry.startAt;
                  final hour = time.hour.toString().padLeft(2, '0');
                  final minute = time.minute.toString().padLeft(2, '0');
                  return '$hour:$minute  ${entry.subjectName}';
                })
                .join('\n'),
    );

    await HomeWidget.updateWidget(androidName: 'BtlSmallWidget');
    await HomeWidget.updateWidget(androidName: 'BtlLargeWidget');
  }
}
