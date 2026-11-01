package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.text.Normalizer
import java.util.Locale
import java.util.TimeZone

internal object NativeSemesterVerifier {
    data class SnapshotBundle(
        val semester: String,
        val appSnapshot: String,
        val widgetSnapshot: String,
    )

    fun verify(
        envelopeJson: String,
        registrationJson: String,
        previousSnapshot: String,
    ): SnapshotBundle {
        val registration = JSONObject(registrationJson)
        val semesterId = registration.optString("id").trim()
        val semesterName = registration.optString("name").trim()
        require(semesterId.isNotEmpty() && semesterName.isNotEmpty()) {
            "Không xác minh được học kỳ mới nhất."
        }
        val registered = registration.optJSONArray("subjects")
            ?: throw IllegalArgumentException("TraCuu chưa tải danh sách môn.")
        require(registered.length() > 0 || registration.optBoolean("confirmedEmpty", false)) {
            "TraCuu chưa xác nhận danh sách môn rỗng."
        }
        val response = JSONObject(envelopeJson).optJSONObject("response")
            ?: throw IllegalArgumentException("QLĐT không trả lịch hợp lệ.")
        val raw = response.optJSONArray("Data")
            ?: throw IllegalArgumentException("QLĐT không trả danh sách lịch.")
        for (index in 0 until raw.length()) {
            val row = raw.optJSONObject(index)
                ?: throw IllegalArgumentException("QLĐT có bản ghi lịch không hợp lệ.")
            require(row.optString("PHANLOAI").uppercase(Locale.ROOT) in setOf("LICHHOC", "LICHTHI")) {
                "QLĐT có loại lịch không xác định."
            }
        }
        val parsed = QldtSnapshotEncoder.encode(envelopeJson, previousSnapshot)
        val app = JSONObject(parsed.appSnapshot)
        val records = app.getJSONArray("records")
        require(records.length() == raw.length()) { "QLĐT trả lịch thiếu trường bắt buộc." }
        val subjects = JSONArray()
        val lookup = LinkedHashMap<String, JSONObject>()
        val sections = HashMap<String, Map<String, String>>()
        for (index in 0 until registered.length()) {
            val subject = registered.optJSONObject(index)
                ?: throw IllegalArgumentException("TraCuu có môn không hợp lệ.")
            val name = widgetSubjectName(subject.optString("name"))
            val normalized = normalize(name)
            require(normalized.isNotEmpty() && !lookup.containsKey(normalized)) {
                "TraCuu có tên môn trống hoặc trùng."
            }
            val classes = subject.optJSONArray("classes") ?: JSONArray()
            val sectionLookup = HashMap<String, String>()
            for (sectionIndex in 0 until classes.length()) {
                val section = classes.optJSONObject(sectionIndex)
                    ?: throw IllegalArgumentException("TraCuu có lớp không hợp lệ.")
                val className = normalize(widgetClassName(section.optString("name")))
                val start = section.optString("startsOn")
                val end = section.optString("endsOn")
                require(className.isNotEmpty() && !sectionLookup.containsKey(className) &&
                    isIsoDate(start) && isIsoDate(end) && start <= end) {
                    "TraCuu có tên lớp hoặc khoảng ngày không hợp lệ."
                }
                sectionLookup[className] = "$start|$end"
            }
            val identity = "${semesterId.length}:$semesterId$normalized"
            val id = "S" + base64Url(identity.toByteArray(Charsets.UTF_8))
            val result = JSONObject()
                .put("subjectId", id)
                .put("name", name)
                .put("normalizedName", normalized)
                .put("studySchedules", JSONArray())
                .put("examSchedules", JSONArray())
            subjects.put(result)
            lookup[normalized] = result
            sections[normalized] = sectionLookup
        }
        val widgetClasses = JSONArray()
        val widgetExams = JSONArray()
        for (index in 0 until records.length()) {
            val row = records.getJSONObject(index)
            val subjectName = normalize(widgetSubjectName(row.getString("subjectName")))
            val subject = lookup[subjectName] ?: continue
            val className = normalize(widgetClassName(row.optString("className")))
            val subjectSections = sections[subjectName].orEmpty()
            val range = subjectSections[className]
            val date = row.getString("startAt").take(10)
            val exam = row.getBoolean("isExam")
            val format = exam && className.isNotEmpty() && EXAM_FORMATS.any {
                className.contains(normalize(it))
            }
            require(range != null || (exam && format && subjectSections.isNotEmpty())) {
                "Không xác minh được lớp của lịch."
            }
            val start = if (exam) subjectSections.values.minOf { it.substringBefore('|') }
                else range!!.substringBefore('|')
            val end = range?.substringAfter('|') ?: start
            require(if (exam) date >= start else withinClassWindow(date, start, end)) {
                "Lịch nằm ngoài học kỳ đăng ký."
            }
            val copy = JSONObject(row.toString())
            subject.getJSONArray(if (exam) "examSchedules" else "studySchedules").put(copy)
            val widget = JSONObject()
                .put("id", "${subject.getString("subjectId")}|${copy.getString("id")}")
                .put("subjectName", subject.getString("name"))
                .put("room", row.getString("room"))
                .put("examForm", if (exam && format) row.optString("className")
                    else row.optString("examForm"))
                .put("startAt", row.getString("startAt"))
                .put("endAt", row.getString("endAt"))
            if (exam) widgetExams.put(widget) else widgetClasses.put(widget)
        }
        val verifiedRecords = JSONArray()
        for (index in 0 until subjects.length()) {
            val subject = subjects.getJSONObject(index)
            for (key in listOf("studySchedules", "examSchedules")) {
                val schedule = subject.getJSONArray(key)
                for (rowIndex in 0 until schedule.length()) {
                    verifiedRecords.put(schedule.getJSONObject(rowIndex))
                }
            }
        }
        val syncedAt = app.getString("syncedAt")
        val semester = JSONObject()
            .put("semesterId", semesterId)
            .put("semesterName", semesterName)
            .put("displayName", app.getString("displayName"))
            .put("syncedAt", syncedAt)
            .put("subjects", subjects)
        app.put("records", verifiedRecords)
        val widget = JSONObject()
            .put("schemaVersion", 1)
            .put("generatedAt", syncedAt)
            .put("classes", widgetClasses)
            .put("exams", widgetExams)
        return SnapshotBundle(semester.toString(), app.toString(), widget.toString())
    }

    private fun normalize(value: String): String = Normalizer.normalize(
        value.trim().replace(Regex("\\s+"), " ").lowercase(Locale.ROOT),
        Normalizer.Form.NFD,
    )

    private fun isIsoDate(value: String): Boolean =
        Regex("\\d{4}-\\d{2}-\\d{2}").matches(value)

    private fun withinClassWindow(date: String, start: String, end: String): Boolean {
        val parser = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply {
            isLenient = false
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val day = parser.parse(date)?.time ?: return false
        val first = parser.parse(start)?.time ?: return false
        val last = parser.parse(end)?.time ?: return false
        val tolerance = 14L * 24 * 60 * 60 * 1000
        return day in (first - tolerance)..(last + tolerance)
    }

    private val EXAM_FORMATS = listOf(
        "trắc nghiệm", "tự luận", "vấn đáp", "bài thi", "thi ",
        "trên máy", "thực hành", "online",
    )

    private fun base64Url(bytes: ByteArray): String {
        val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        val output = StringBuilder()
        for (index in bytes.indices step 3) {
            val first = bytes[index].toInt() and 255
            val second = if (index + 1 < bytes.size) bytes[index + 1].toInt() and 255 else 0
            val third = if (index + 2 < bytes.size) bytes[index + 2].toInt() and 255 else 0
            output.append(alphabet[first ushr 2])
            output.append(alphabet[((first and 3) shl 4) or (second ushr 4)])
            if (index + 1 < bytes.size) output.append(alphabet[((second and 15) shl 2) or (third ushr 6)])
            if (index + 2 < bytes.size) output.append(alphabet[third and 63])
        }
        return output.toString()
    }
}

internal fun widgetSubjectName(value: String): String = value.trim()
    .replaceFirst(Regex("^Môn\\s+", RegexOption.IGNORE_CASE), "")
    .replaceFirst(Regex("-\\d+-\\d+-\\d+\\([^)]*\\)(?:\\.[A-Za-z0-9_]+)?$"), "")
    .trim()

internal fun widgetClassName(value: String): String =
    value.split(Regex("<br\\s*/?>", RegexOption.IGNORE_CASE)).first().trim()
