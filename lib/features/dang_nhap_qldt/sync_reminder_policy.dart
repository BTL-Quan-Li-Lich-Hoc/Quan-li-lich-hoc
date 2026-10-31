final class SyncReminderPolicy {
  const new();

  bool shouldRemind({
    required DateTime now,
    required DateTime? lastSuccessfulSync,
    required DateTime? lastReminder,
  }) {
    if (lastSuccessfulSync == null) return false;
    final dueAt = lastSuccessfulSync.add(const Duration(days: 2));
    if (!now.isAfter(dueAt)) return false;
    return lastReminder == null ||
        lastReminder.isBefore(lastSuccessfulSync) ||
        DateTime(now.year, now.month, now.day).isAfter(
          DateTime(lastReminder.year, lastReminder.month, lastReminder.day),
        );
  }
}
