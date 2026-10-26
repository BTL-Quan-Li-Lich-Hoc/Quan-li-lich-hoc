const List<String> _weekdayNames = <String>[
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

String formatScheduleDay(DateTime value) {
  return '${_weekdayNames[value.weekday - 1]}, '
      '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
}

String formatScheduleTime(DateTime value) {
  return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String formatScheduleTimeRange(DateTime start, DateTime end) {
  return '${formatScheduleTime(start)} – ${formatScheduleTime(end)}';
}

String formatScheduleWeek(DateTime selectedDay) {
  final start = startOfScheduleWeek(selectedDay);
  final end = start.add(const Duration(days: 6));
  return '${_twoDigits(start.day)}/${_twoDigits(start.month)} – '
      '${_twoDigits(end.day)}/${_twoDigits(end.month)}';
}

DateTime startOfScheduleWeek(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool isSameScheduleDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
