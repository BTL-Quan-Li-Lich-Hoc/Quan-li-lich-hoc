package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONObject
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

internal data class PlannedExamReminder(
    val key: String,
    val subjects: List<String>,
    val daysBefore: Int,
    val atMillis: Long,
    val milestoneKeys: Set<String>,
)

internal data class ExamReminderPlan(
    val schedule: List<PlannedExamReminder>,
    val due: List<PlannedExamReminder>,
    val cancel: Set<String>,
)

internal object ExamReminderPlanner {
    fun plan(
        semesterJson: String,
        nowMillis: Long,
        scheduled: Set<String>,
        delivered: Set<String>,
    ): ExamReminderPlan {
        val today = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val subjects = JSONObject(semesterJson).getJSONArray("subjects")
        val candidates = mutableListOf<PlannedExamReminder>()
        for (index in 0 until subjects.length()) {
            val subject = subjects.getJSONObject(index)
            val exams = subject.getJSONArray("examSchedules")
            for (examIndex in 0 until exams.length()) {
                val exam = exams.getJSONObject(examIndex)
                val parse = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).apply {
                    isLenient = false
                }
                val startAt = exam.getString("startAt")
                val endAt = exam.getString("endAt")
                val start = parse.parse(startAt.take(16)) ?: continue
                val end = parse.parse(endAt.take(16)) ?: continue
                if (end.time <= nowMillis) continue
                val identity = listOf(
                    subject.getString("subjectId"), exam.getString("id"), startAt, endAt,
                    exam.optString("room"), exam.optString("className"), exam.optString("examForm"),
                ).joinToString("|")
                val startDay = Calendar.getInstance().apply { time = start }
                val daysLeft = calendarDays(today, startDay)
                if (daysLeft <= 0) continue
                for (milestone in listOf(7, 3, 1)) {
                    val tierKey = sha256("$identity|$milestone")
                    if (tierKey in delivered) continue
                    if (daysLeft > milestone) {
                        val at = Calendar.getInstance().apply {
                            time = start
                            add(Calendar.DAY_OF_YEAR, -milestone)
                            set(Calendar.HOUR_OF_DAY, 9)
                            set(Calendar.MINUTE, 0)
                            set(Calendar.SECOND, 0)
                            set(Calendar.MILLISECOND, 0)
                        }.timeInMillis
                        candidates.add(PlannedExamReminder(
                            sha256("day|$at|$milestone"), listOf(subject.getString("name")),
                            milestone, at, setOf(tierKey)))
                    } else if (daysLeft == 1 && milestone == 1 ||
                        daysLeft in 2..3 && milestone == 3 ||
                        daysLeft in 4..7 && milestone == 7) {
                        candidates.add(PlannedExamReminder(
                            sha256("due|$daysLeft"), listOf(subject.getString("name")),
                            daysLeft, nowMillis, setOf(tierKey)))
                    }
                }
            }
        }
        fun grouped(items: List<PlannedExamReminder>): List<PlannedExamReminder> =
            items.groupBy { it.key }.values.map { group ->
                group.first().copy(
                    subjects = group.flatMap { it.subjects }.distinct(),
                    milestoneKeys = group.flatMap { it.milestoneKeys }.toSet(),
                )
            }
        val future = grouped(candidates.filter { it.atMillis > nowMillis })
        val due = grouped(candidates.filter { it.atMillis <= nowMillis })
        return ExamReminderPlan(
            future.filter { it.key !in scheduled },
            due,
            scheduled - future.map { it.key }.toSet(),
        )
    }

    private fun calendarDays(a: Calendar, b: Calendar): Int {
        val first = a.clone() as Calendar
        val second = b.clone() as Calendar
        for (day in listOf(first, second)) {
            day.set(Calendar.HOUR_OF_DAY, 12)
            day.set(Calendar.MINUTE, 0)
            day.set(Calendar.SECOND, 0)
            day.set(Calendar.MILLISECOND, 0)
        }
        var count = 0
        while (first.before(second)) {
            first.add(Calendar.DAY_OF_YEAR, 1)
            count++
        }
        return count
    }

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}
