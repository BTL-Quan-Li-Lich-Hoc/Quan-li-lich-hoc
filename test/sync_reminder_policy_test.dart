import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/sync_reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SyncReminderPolicy();
  final sync = DateTime(2026, 9, 20, 15);

  test(
    'does not remind at or before two days or without a successful sync',
    () {
      expect(
        policy.shouldRemind(
          now: sync.add(const Duration(days: 2)),
          lastSuccessfulSync: sync,
          lastReminder: null,
        ),
        isFalse,
      );
      expect(
        policy.shouldRemind(
          now: sync.add(const Duration(days: 4)),
          lastSuccessfulSync: null,
          lastReminder: null,
        ),
        isFalse,
      );
    },
  );

  test(
    'a successful sync resets reminder age; repeated reminders are spaced',
    () {
      final due = sync.add(const Duration(days: 2, milliseconds: 1));
      expect(
        policy.shouldRemind(
          now: due,
          lastSuccessfulSync: sync,
          lastReminder: sync.subtract(const Duration(days: 1)),
        ),
        isTrue,
      );
      expect(
        policy.shouldRemind(
          now: due.add(const Duration(hours: 1)),
          lastSuccessfulSync: sync,
          lastReminder: due,
        ),
        isFalse,
      );
      expect(
        policy.shouldRemind(
          now: due.add(const Duration(days: 1)),
          lastSuccessfulSync: sync,
          lastReminder: due,
        ),
        isTrue,
      );
    },
  );

  test(
    'reminds once per local day and resets after the next successful sync',
    () {
      final due = DateTime(2026, 9, 22, 16);
      expect(
        policy.shouldRemind(
          now: due,
          lastSuccessfulSync: sync,
          lastReminder: DateTime(2026, 9, 22, 9),
        ),
        isFalse,
      );
      expect(
        policy.shouldRemind(
          now: DateTime(2026, 9, 23, 9),
          lastSuccessfulSync: sync,
          lastReminder: due,
        ),
        isTrue,
      );
      expect(
        policy.shouldRemind(
          now: DateTime(2026, 9, 23, 9),
          lastSuccessfulSync: DateTime(2026, 9, 23, 8),
          lastReminder: due,
        ),
        isFalse,
      );
    },
  );
}
