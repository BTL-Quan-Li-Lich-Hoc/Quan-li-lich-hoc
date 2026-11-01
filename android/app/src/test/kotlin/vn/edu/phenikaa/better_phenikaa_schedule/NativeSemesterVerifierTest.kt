package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class NativeSemesterVerifierTest {
    private val registration = """
        {"id":"2026_2027_1","name":"2026_2027_1","subjects":[
          {"name":"Thiết kế web nâng cao","classes":[
            {"name":"WEB-2026-LT","startsOn":"2026-08-17","endsOn":"2026-11-01"}
          ]},
          {"name":"Toán cao cấp","classes":[]}
        ]}
    """.trimIndent()

    private fun envelope(date: String = "23/09/2026", section: String = "WEB-2026-LT") = """
        {"name":"Sinh viên","response":{"Success":true,"Data":[
          {"PHANLOAI":"LICHHOC","TENHOCPHAN":"Thiết kế web nâng cao",
           "TENLOPHOCPHAN":"$section","NGAYHOC":"$date",
           "GIOBATDAU":7,"PHUTBATDAU":0,"GIOKETTHUC":9,"PHUTKETTHUC":0,
           "PHONGHOC_TEN":"A1"}
        ]}}
    """.trimIndent()

    @Test fun aRegisteredSubjectWithoutScheduleIsKept() {
        val result = NativeSemesterVerifier.verify(envelope(), registration, "")
        val semester = JSONObject(result.semester)
        val subjects = semester.getJSONArray("subjects")
        assertEquals(2, subjects.length())
        assertEquals(0, subjects.getJSONObject(1).getJSONArray("studySchedules").length())
        val subject = subjects.getJSONObject(0)
        val rawId = subject.getJSONArray("studySchedules").getJSONObject(0).getString("id")
        assertEquals(true, rawId.startsWith("class|"))
        assertEquals(1, JSONObject(result.widgetSnapshot).getJSONArray("classes").length())
    }

    @Test fun aSameNameOldClassCannotBeLinked() {
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(envelope(section = "WEB-2025-LT"), registration, "")
        }
    }

    @Test fun aPartialResponseDoesNotOverwriteThePreviousSnapshot() {
        val malformed = envelope().replace("\"TENLOPHOCPHAN\":\"WEB-2026-LT\",", "")
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(malformed, registration, "")
        }
    }

    @Test fun anOldExamWithTheSameClassNameIsRejected() {
        val exam = envelope(date = "10/12/2025")
            .replace("LICHHOC", "LICHTHI")
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(exam, registration, "")
        }
    }

    @Test fun aVerifiedExamIsAttachedToTheSubjectAndWidget() {
        val exam = envelope(date = "10/12/2026")
            .replace("LICHHOC", "LICHTHI")
        val result = NativeSemesterVerifier.verify(exam, registration, "")
        val subject = JSONObject(result.semester).getJSONArray("subjects").getJSONObject(0)
        assertEquals(1, subject.getJSONArray("examSchedules").length())
        assertEquals(1, JSONObject(result.widgetSnapshot).getJSONArray("exams").length())
    }

    @Test fun anExamFormatLabelAndNearbyClassDatesAreVerified() {
        val before = NativeSemesterVerifier.verify(
            envelope(date = "10/08/2026"), registration, "",
        )
        assertEquals(1, JSONObject(before.widgetSnapshot).getJSONArray("classes").length())
        val after = NativeSemesterVerifier.verify(
            envelope(date = "02/11/2026"), registration, "",
        )
        assertEquals(1, JSONObject(after.widgetSnapshot).getJSONArray("classes").length())
        val exam = envelope(date = "24/10/2026", section = "Trắc nghiệm trên máy 30p")
            .replace("LICHHOC", "LICHTHI")
        val result = NativeSemesterVerifier.verify(exam, registration, "")
        val widget = JSONObject(result.widgetSnapshot).getJSONArray("exams").getJSONObject(0)
        assertEquals("Trắc nghiệm trên máy 30p", widget.getString("examForm"))
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(
                exam.replace("Trắc nghiệm trên máy 30p", "WEB-2025-LT"), registration, "",
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(
                envelope(date = "01/07/2026"), registration, "",
            )
        }
    }

    @Test fun attendanceMarkupIsIgnoredButAnotherClassIsStillRejected() {
        val actual = registration.replace("WEB-2026-LT", "Kỹ thuật phần mềm-1-1-26(COUR02)")
            .replace("Thiết kế web nâng cao", "Môn Kỹ thuật phần mềm-1-1-26(COUR02)")
        val row = envelope(section = "Kỹ thuật phần mềm-1-1-26(COUR02)<br>Có mặt<br>")
            .replace("Thiết kế web nâng cao", "Môn Kỹ thuật phần mềm-1-1-26(COUR02)")
        val result = NativeSemesterVerifier.verify(row, actual, "")
        val subject = JSONObject(result.semester).getJSONArray("subjects").getJSONObject(0)
        assertEquals("Kỹ thuật phần mềm", subject.getString("name"))
        assertEquals(1, subject.getJSONArray("studySchedules").length())
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(
                row.replace("(COUR02)<br>", "(COUR03)<br>"), actual, "",
            )
        }
    }
}
