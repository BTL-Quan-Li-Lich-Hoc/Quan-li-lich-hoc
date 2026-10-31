package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class SyncStaleReminderPolicyTest {
    @Test fun twoDaysAndDailyDeduplication() {
        val start = Calendar.getInstance().apply {
            set(2026, Calendar.SEPTEMBER, 20, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val day = 24L * 60 * 60 * 1000
        assertFalse(SyncStaleReminderPolicy.due(start + day, start, 0))
        assertFalse(SyncStaleReminderPolicy.due(start + 2 * day, start, 0))
        assertTrue(SyncStaleReminderPolicy.due(start + 2 * day + 1, start, 0))
        val reminder = start + 2 * day + 1
        assertFalse(SyncStaleReminderPolicy.due(reminder + 60_000, start, reminder))
        assertTrue(SyncStaleReminderPolicy.due(start + 3 * day, start, reminder))
        assertFalse(SyncStaleReminderPolicy.due(start + 3 * day, start + 3 * day, reminder))
    }
}
