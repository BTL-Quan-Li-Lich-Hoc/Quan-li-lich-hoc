import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';
import 'package:flutter/material.dart';

class ScheduleDifferenceSheet extends StatelessWidget {
  const new({required this.difference, super.key});

  final SemesterDifference? difference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = this.difference;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Thay đổi lịch gần nhất', style: theme.textTheme.titleLarge),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (difference == null ||
                        difference.initial ||
                        !difference.hasChanges)
                      const ListTile(
                        title: Text(
                          'Chưa có thay đổi so với lần đồng bộ trước.',
                        ),
                      )
                    else ...<Widget>[
                      for (final name in difference.addedSubjects)
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline),
                          title: Text('Môn mới: $name'),
                        ),
                      for (final name in difference.removedSubjects)
                        ListTile(
                          leading: const Icon(Icons.remove_circle_outline),
                          title: Text('Môn đã hủy: $name'),
                        ),
                      _section('Lịch học', difference.study),
                      _section('Lịch thi', difference.exams),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, ScheduleDifference data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SizedBox(height: 12),
      Text(
        '$title · ${data.added} mới, ${data.modified} đổi, ${data.removed} hủy',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      if (data.details.isEmpty)
        ListTile(
          title: Text(
            data.hasChanges
                ? 'Bản đồng bộ cũ chỉ lưu số lượng, chưa lưu chi tiết.'
                : 'Không có thay đổi.',
          ),
        ),
      for (final item in data.details)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${switch (item.kind) {
                    'added' => 'Mới',
                    'removed' => 'Đã hủy',
                    _ => 'Đã đổi',
                  }} · '
                  '${(item.after ?? item.before)!.subjectName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.before != null) Text('Trước: ${_row(item.before!)}'),
                if (item.after != null) Text('Sau: ${_row(item.after!)}'),
              ],
            ),
          ),
        ),
    ],
  );

  String _row(ScheduleRecord row) {
    String two(int number) => number.toString().padLeft(2, '0');
    final start = row.startAt;
    final end = row.endAt;
    final date = '${two(start.day)}/${two(start.month)}/${start.year}';
    final time =
        '${two(start.hour)}:${two(start.minute)}–${two(end.hour)}:${two(end.minute)}';
    return '$date · $time · ${row.room.isEmpty ? 'Chưa có phòng' : row.room}'
        '${row.examForm.isEmpty ? '' : ' · ${row.examForm}'}';
  }
}
