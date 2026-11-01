package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

class ExamReminderPlannerTest {
    private fun semester(date: String = "2026-12-10T08:00:00.000", room: String = "C3") = """
        {"subjects":[{"subjectId":"stable","name":"Thiết kế web nâng cao",
        "examSchedules":[{"id":"exam","startAt":"$date","endAt":"2026-12-10T10:00:00.000",
        "room":"$room","className":"WEB-2026-LT","examForm":""}]}]}
    """.trimIndent()

    private val now = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2026-12-01")!!.time

    @Test fun firstAndIdenticalSyncDoNotDuplicateReminders() {
        val first = ExamReminderPlanner.plan(semester(), now, emptySet(), emptySet())
        assertEquals(listOf(7, 3, 1), first.schedule.map { it.daysBefore })
        val keys = first.schedule.map { it.key }.toSet()
        val repeated = ExamReminderPlanner.plan(semester(), now, keys, emptySet())
        assertTrue(repeated.schedule.isEmpty())
        assertTrue(repeated.cancel.isEmpty())
    }

    @Test fun aMovedOrCancelledExamCancelsAllOldReminders() {
        val original = ExamReminderPlanner.plan(semester(), now, emptySet(), emptySet())
        val keys = original.schedule.map { it.key }.toSet()
        val moved = ExamReminderPlanner.plan(semester("2026-12-15T09:00:00.000"), now, keys, emptySet())
        assertEquals(keys, moved.cancel)
        assertEquals(3, moved.schedule.size)
        val cancelled = ExamReminderPlanner.plan("""{"subjects":[]}""", now, keys, emptySet())
        assertEquals(keys, cancelled.cancel)
    }

    @Test fun deliveredMilestoneIsNeverScheduledAgain() {
        val first = ExamReminderPlanner.plan(semester(), now, emptySet(), emptySet())
        val delivered = first.schedule.first().milestoneKeys
        val repeated = ExamReminderPlanner.plan(semester(), now, emptySet(), delivered)
        assertEquals(2, repeated.schedule.size)
    }

    @Test fun missedSevenDayMilestoneCatchesUpAtFiveThenThreeThenTomorrow() {
        val five = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2026-12-05")!!.time
        val first = ExamReminderPlanner.plan(semester(), five, emptySet(), emptySet())
        assertEquals(listOf(5), first.due.map { it.daysBefore })
        val delivered = first.due.single().milestoneKeys
        val three = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2026-12-07")!!.time
        val second = ExamReminderPlanner.plan(semester(), three, emptySet(), delivered)
        assertEquals(listOf(3), second.due.map { it.daysBefore })
        val tomorrow = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2026-12-09")!!.time
        val third = ExamReminderPlanner.plan(semester(), tomorrow, emptySet(),
            delivered + second.due.single().milestoneKeys)
        assertEquals(listOf(1), third.due.map { it.daysBefore })
    }

    @Test fun twoExamsOnSameDayMakeOneReminder() {
        val json = JSONObject(semester())
        val subjects = json.getJSONArray("subjects")
        val second = JSONObject(subjects.getJSONObject(0).toString())
            .put("subjectId", "second").put("name", "Môn B")
        subjects.put(second)
        val seven = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2026-12-03")!!.time
        val plan = ExamReminderPlanner.plan(json.toString(), seven, emptySet(), emptySet())
        assertEquals(1, plan.due.size)
        assertEquals(2, plan.due.single().subjects.size)
    }
}
