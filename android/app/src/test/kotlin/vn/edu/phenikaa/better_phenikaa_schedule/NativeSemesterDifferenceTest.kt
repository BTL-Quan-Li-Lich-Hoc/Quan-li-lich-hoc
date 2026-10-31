package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class NativeSemesterDifferenceTest {
    private fun semester(room: String = "A1", examDate: String = "2026-12-10T08:00:00.000") = """
        {"subjects":[{"subjectId":"stable","name":"Thiết kế web nâng cao",
        "studySchedules":[{"subjectName":"Thiết kế web nâng cao","className":"WEB-2026-LT",
        "room":"$room","examForm":"","startAt":"2026-09-23T07:00:00.000",
        "endAt":"2026-09-23T09:00:00.000","periodStart":null,"periodEnd":null}],
        "examSchedules":[{"subjectName":"Thiết kế web nâng cao","className":"WEB-2026-LT",
        "room":"C3","examForm":"","startAt":"$examDate",
        "endAt":"2026-12-10T10:00:00.000","periodStart":null,"periodEnd":null}]}]}
    """.trimIndent()

    @Test fun initialAndRepeatedSyncAreDistinct() {
        val initial = JSONObject(NativeSemesterDifference.compare(null, semester()))
        assertEquals(true, initial.getBoolean("initial"))
        val repeated = JSONObject(NativeSemesterDifference.compare(semester(), semester()))
        assertEquals(false, repeated.getBoolean("initial"))
        assertEquals(0, repeated.getJSONObject("study").getInt("modified"))
        assertEquals(0, repeated.getJSONObject("exams").getInt("added"))
    }

    @Test fun roomAndExamDateChangesAreReportedOnce() {
        val changed = JSONObject(NativeSemesterDifference.compare(
            semester(), semester(room = "B2", examDate = "2026-12-15T09:00:00.000"),
        ))
        assertEquals(1, changed.getJSONObject("study").getInt("modified"))
        assertEquals(1, changed.getJSONObject("exams").getInt("modified"))
        val room = changed.getJSONObject("study").getJSONArray("details").getJSONObject(0)
        assertEquals("A1", room.getJSONObject("before").getString("room"))
        assertEquals("B2", room.getJSONObject("after").getString("room"))
    }

    @Test fun addingAndRemovingSubjectsIncludesTheirSchedules() {
        val empty = """{"subjects":[]}"""
        val added = JSONObject(NativeSemesterDifference.compare(empty, semester()))
        assertEquals(1, added.getJSONArray("addedSubjects").length())
        assertEquals(1, added.getJSONObject("study").getInt("added"))
        assertEquals(1, added.getJSONObject("exams").getInt("added"))
        assertEquals("added", added.getJSONObject("study").getJSONArray("details")
            .getJSONObject(0).getString("kind"))
        val removed = JSONObject(NativeSemesterDifference.compare(semester(), empty))
        assertEquals(1, removed.getJSONArray("removedSubjects").length())
        assertEquals(1, removed.getJSONObject("exams").getInt("removed"))
    }
}
