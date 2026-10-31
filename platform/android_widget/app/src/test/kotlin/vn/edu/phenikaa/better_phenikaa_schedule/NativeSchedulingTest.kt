package vn.edu.phenikaa.better_phenikaa_schedule

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeSchedulingTest {
    @Test
    fun nextSixAmUsesLocalWallClock() {
        val now = Calendar.getInstance(TimeZone.getTimeZone("Asia/Ho_Chi_Minh")).apply {
            set(2026, Calendar.SEPTEMBER, 22, 5, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }
        assertEquals(30L * 60L * 1000L, DailySyncScheduler.delayUntilNextSixAm(now))

        now.set(2026, Calendar.SEPTEMBER, 22, 6, 0, 0)
        assertEquals(24L * 60L * 60L * 1000L, DailySyncScheduler.delayUntilNextSixAm(now))
    }

    @Test
    fun widgetTimelineAnchorsToNextUnfinishedClassWithoutReordering() {
        val items = listOf(
            widgetClass("past", "2026-09-22T07:00:00", "2026-09-22T09:00:00"),
            widgetClass("next", "2026-09-22T10:00:00", "2026-09-22T12:00:00"),
            widgetClass("tomorrow", "2026-09-23T07:00:00", "2026-09-23T09:00:00"),
        )
        val collection = WidgetTimeline.arrange(
            items.reversed(),
            selectedDate = "2026-09-22",
            today = "2026-09-22",
            now = "2026-09-22T09:30:00",
        )
        assertEquals(listOf("past", "next", "tomorrow"), collection.items.map { it.id })
        assertEquals(1, collection.selectedIndex)
        assertTrue(collection.selectedIndex in collection.items.indices)
    }

    private fun widgetClass(id: String, start: String, end: String) = WidgetClass(
        id = id,
        subject = id,
        room = "A1",
        time = "",
        startAt = start,
        endAt = end,
        dateKey = start.take(10),
    )
}
