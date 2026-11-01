package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExamChangeNotifierTest {
    private val semester = """{"subjects":[
        {"examSchedules":[{},{}]}, {"examSchedules":[]}
    ]}"""

    @Test fun firstVerifiedImportIsNotAChange() {
        assertNull(ExamChangeNotifier.messageFor(semester, """{"initial":true}"""))
    }

    @Test fun laterSyncSummarizesAnyExamChange() {
        assertEquals("Lịch thi của bạn vừa có thay đổi. Kiểm tra lại để tránh nhầm lịch nhé.",
            ExamChangeNotifier.messageFor(semester,
                """{"initial":false,"exams":{"added":1,"modified":1,"removed":0}}"""))
        assertEquals("Lịch thi của bạn vừa có thay đổi. Kiểm tra lại để tránh nhầm lịch nhé.",
            ExamChangeNotifier.messageFor(semester,
                """{"initial":false,"exams":{"added":0,"modified":0,"removed":1}}"""))
    }

    @Test fun sourceChangesClassifyStudyExamBothOrNone() {
        fun diff(study: Int, exam: Int) =
            """{"initial":false,"study":{"added":$study},"exams":{"removed":$exam}}"""
        assertEquals(AssistantEvent.study_changed, ExamChangeNotifier.eventFor(diff(1, 0)))
        assertEquals(AssistantEvent.exam_changed, ExamChangeNotifier.eventFor(diff(0, 1)))
        assertEquals(AssistantEvent.study_and_exam_changed,
            ExamChangeNotifier.eventFor(diff(1, 1)))
        assertNull(ExamChangeNotifier.eventFor(diff(0, 0)))
        assertNull(ExamChangeNotifier.eventFor("""{"initial":true}"""))
    }
}
