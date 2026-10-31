package vn.edu.phenikaa.better_phenikaa_schedule

import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

internal class NativeQldtWidgetSync(sessionJson: String) {
    sealed interface Result {
        data class Success(val envelope: String, val registration: String) : Result
        data class Failure(val message: String) : Result
    }

    private data class Session(
        val tokenJwt: String,
        val userId: String,
        val iM: String,
        val appId: String,
        val functionId: String,
        val cookie: String,
        val displayName: String,
    )

    private val cancelled = AtomicBoolean(false)
    private val session = parseSession(sessionJson)

    fun cancel() {
        cancelled.set(true)
    }

    fun run(): Result {
        return try {
            requireSession()
        val registration = fetchRegistration()
        if (cancelled.get()) {
            Result.Failure("SYNC_STOPPED: Tác vụ đồng bộ đã dừng.")
        } else {
            val range = registrationRange(registration)
                ?: return Result.Failure(
                    "NO_SUBJECTS: Học kỳ mới chưa có môn đăng ký hoặc đã hết hạn.",
                )
            val schedule = fetchSchedule(range.first, range.second)
            if (cancelled.get()) {
                Result.Failure("SYNC_STOPPED: Tác vụ đồng bộ đã dừng.")
            } else {
                Result.Success(schedule, registration)
            }
        }
        } catch (error: NativeSyncException) {
            Result.Failure(error.message ?: "NATIVE_SYNC_FAILED")
        } catch (error: Exception) {
            Result.Failure(
                "NATIVE_SYNC_EXCEPTION: ${error.javaClass.simpleName}: " +
                    error.message.orEmpty().take(120),
            )
        }
    }

    private fun fetchRegistration(): String {
        val semesters = rows(
            post(
                ACTION_SEMESTERS,
                FUNC_SEMESTERS,
                JSONObject().put("strDaoTao_ThoiGianDaoTao_Id", JSONObject.NULL),
            ),
        )

        data class Semester(val id: String, val name: String, val year: Int, val term: Int)

        val choices = buildList {
            for (index in 0 until semesters.length()) {
                val row = semesters.optJSONObject(index) ?: continue
                val name = row.optString("THOIGIAN").trim()
                val id = row.optString("ID").trim()
                val match = SEMESTER_REGEX.matchEntire(name) ?: continue
                val firstYear = match.groupValues[1].toIntOrNull() ?: continue
                val secondYear = match.groupValues[2].toIntOrNull() ?: continue
                val term = match.groupValues[3].toIntOrNull() ?: continue
                if (id.isBlank() || secondYear != firstYear + 1) continue
                add(Semester(id, name, firstYear, term))
            }
        }.sortedWith(compareByDescending<Semester> { it.year }.thenByDescending { it.term })

        val latest = choices.firstOrNull()
            ?: throw NativeSyncException("NO_SEMESTER: QLĐT không trả học kỳ hợp lệ.")

        val plans = rows(
            post(
                ACTION_PLANS,
                FUNC_PLANS,
                JSONObject().put("strDaoTao_ThoiGianDaoTao_Id", latest.id),
            ),
        )
        val planIds = linkedSetOf<String>()
        val planSemesterIds = linkedSetOf<String>()
        for (index in 0 until plans.length()) {
            val row = plans.optJSONObject(index) ?: continue
            val code = row.optString("MAKEHOACH").trim()
            if (code != latest.name && !code.startsWith(latest.name + ",")) continue
            row.optString("ID").trim().takeIf { it.isNotEmpty() }?.let(planIds::add)
            row.optString("DAOTAO_THOIGIANDAOTAO_ID").trim()
                .takeIf { it.isNotEmpty() }?.let(planSemesterIds::add)
        }
        if (planIds.size != 1 || planSemesterIds.size != 1) {
            throw NativeSyncException("PLAN_AMBIGUOUS: Không xác định được kế hoạch học kỳ.")
        }

        val planId = planIds.single()
        val planSemesterId = planSemesterIds.single()
        val registrations = rows(
            post(
                ACTION_SUBJECTS,
                FUNC_SUBJECTS,
                JSONObject()
                    .put("strDaoTao_ChuongTrinh_Id", "")
                    .put("strDangKy_KeHoachDangKy_Id", planId)
                    .put("strNguoiThucHien_Id", session.userId)
                    .put("strDaoTao_ThoiGianDaoTao_Id", latest.id),
            ),
        )

        data class SubjectRow(
            val name: String,
            val classes: LinkedHashMap<String, JSONObject>,
        )
        val subjects = linkedMapOf<String, SubjectRow>()

        for (index in 0 until registrations.length()) {
            val row = registrations.optJSONObject(index)
                ?: throw NativeSyncException("INVALID_REGISTRATION: Dòng đăng ký không hợp lệ.")
            if (
                row.optString("DANGKY_KEHOACHDANGKY_ID") != planId ||
                (
                    row.optString("DAOTAO_THOIGIANDAOTAO_ID") != latest.id &&
                        row.optString("DAOTAO_THOIGIANDAOTAO_ID") != planSemesterId
                    ) ||
                row.optString("DAOTAO_HOCPHAN_ID").isBlank() ||
                row.optString("DAOTAO_HOCPHAN_TEN").isBlank() ||
                row.optString("DANGKY_LOPHOCPHAN_ID").isBlank() ||
                row.optString("DANGKY_LOPHOCPHAN_TEN").isBlank()
            ) {
                throw NativeSyncException(
                    "INVALID_REGISTRATION: Kết quả đăng ký sai kế hoạch hoặc học kỳ.",
                )
            }

            val subjectId = row.getString("DAOTAO_HOCPHAN_ID")
            val subjectName = row.getString("DAOTAO_HOCPHAN_TEN")
            val classId = row.getString("DANGKY_LOPHOCPHAN_ID")
            val className = row.getString("DANGKY_LOPHOCPHAN_TEN")
            val startsOn = toIsoDate(row.getString("NGAYBATDAU"))
            val endsOn = toIsoDate(row.getString("NGAYKETTHUC"))
            if (endsOn < startsOn) {
                throw NativeSyncException("INVALID_DATE: Khoảng ngày lớp không hợp lệ.")
            }

            val subject = subjects.getOrPut(subjectId) {
                SubjectRow(subjectName, linkedMapOf())
            }
            if (subject.name != subjectName) {
                throw NativeSyncException("INVALID_SUBJECT: Tên môn không nhất quán.")
            }
            subject.classes.putIfAbsent(
                classId,
                JSONObject()
                    .put("name", className)
                    .put("startsOn", startsOn)
                    .put("endsOn", endsOn),
            )
        }

        val encodedSubjects = JSONArray()
        subjects.values.forEach { subject ->
            val classes = JSONArray()
            subject.classes.values.forEach(classes::put)
            encodedSubjects.put(
                JSONObject()
                    .put("name", subject.name)
                    .put("classes", classes),
            )
        }

        return JSONObject()
            .put("id", latest.name)
            .put("name", latest.name)
            .put("confirmedEmpty", registrations.length() == 0)
            .put(
                "route",
                JSONObject()
                    .put("userId", session.userId)
                    .put("semesterId", latest.id)
                    .put("semesterName", latest.name)
                    .put("planId", planId),
            )
            .put("subjects", encodedSubjects)
            .toString()
    }

    private fun fetchSchedule(start: String, end: String): String {
        val response = post(
            ACTION_SCHEDULE,
            FUNC_SCHEDULE,
            JSONObject().put("strNgayBatDau", start).put("strNgayKetThuc", end),
        )
        return JSONObject()
            .put("name", session.displayName)
            .put("response", response)
            .toString()
    }

    private fun post(action: String, func: String, extra: JSONObject): JSONObject {
        if (cancelled.get()) {
            throw NativeSyncException("SYNC_STOPPED: Tác vụ đồng bộ đã dừng.")
        }

        val payload = JSONObject()
            .put("action", action)
            .put("func", func)
            .put("iM", session.iM)
            .put("strQLSV_NguoiHoc_Id", session.userId)
        extra.keys().forEach { key -> payload.put(key, extra.get(key)) }
        if (!payload.has("strChucNang_Id")) payload.put("strChucNang_Id", session.functionId)
        if (!payload.has("strNguoiThucHien_Id")) {
            payload.put("strNguoiThucHien_Id", session.userId)
        }
        if (!payload.has("strVaiTroDangNhap_Id")) {
            payload.put("strVaiTroDangNhap_Id", session.appId)
        }
        if (!payload.has("strChucNangHeThong_Id")) {
            payload.put("strChucNangHeThong_Id", session.functionId)
        }

        val apiRoot = when (action.substringBefore('_')) {
            "DKH" -> "/dangkyhocapi3/api"
            "SV" -> "/sinhvienapi3/api"
            else -> throw NativeSyncException("NATIVE_ROUTE: API prefix không hỗ trợ.")
        }
        val key = action.substringAfter('/')
        val connection = URL(ROOT + apiRoot + "/" + action).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer ${session.tokenJwt}")
            connection.setRequestProperty(
                "Accept",
                "application/json, text/javascript, */*; q=0.01",
            )
            connection.setRequestProperty(
                "Content-Type",
                "application/x-www-form-urlencoded; charset=UTF-8",
            )
            if (session.cookie.isNotBlank()) {
                connection.setRequestProperty("Cookie", session.cookie)
            }

            val body = "A=" + URLEncoder.encode(
                xorEncode(payload.toString(), key),
                StandardCharsets.UTF_8.name(),
            )
            connection.outputStream.use {
                it.write(body.toByteArray(StandardCharsets.UTF_8))
            }

            val status = connection.responseCode
            val source = if (status in 200..299) connection.inputStream else connection.errorStream
            val responseText = source?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }
                .orEmpty()
            if (status != 200) {
                throw NativeSyncException("HTTP_$status: QLĐT trả HTTP $status.")
            }

            val envelope = JSONObject(responseText)
            if (!envelope.optBoolean("Success", false)) {
                throw NativeSyncException("REQUEST_ERROR: QLĐT Success != true.")
            }
            val encrypted = envelope.optJSONObject("Data")?.optString("B").orEmpty()
            if (encrypted.isNotEmpty()) {
                val parsed = org.json.JSONTokener(xorDecode(encrypted, session.iM)).nextValue()
                envelope.put("Data", parsed)
            }
            if (envelope.optJSONArray("Data") == null) {
                throw NativeSyncException("INVALID_RESPONSE: QLĐT Data không phải danh sách.")
            }
            return envelope
        } finally {
            connection.disconnect()
        }
    }

    private fun rows(envelope: JSONObject): JSONArray =
        envelope.optJSONArray("Data")
            ?: throw NativeSyncException("INVALID_RESPONSE: QLĐT Data không phải danh sách.")

    private fun registrationRange(raw: String): Pair<String, String>? {
        val subjects = JSONObject(raw).getJSONArray("subjects")
        val dates = mutableListOf<String>()
        for (index in 0 until subjects.length()) {
            val classes = subjects.getJSONObject(index).getJSONArray("classes")
            for (classIndex in 0 until classes.length()) {
                val value = classes.getJSONObject(classIndex).getString("startsOn")
                require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(value))
                dates.add(value)
            }
        }
        val first = dates.minOrNull() ?: return null
        val input = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply { isLenient = false }
        val output = SimpleDateFormat("dd/MM/yyyy", Locale.ROOT)
        val start = input.parse(first) ?: return null
        val expiry = Calendar.getInstance().apply {
            time = start
            add(Calendar.MONTH, 4)
            add(Calendar.DAY_OF_MONTH, 7)
        }
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (today.after(expiry)) return null
        return output.format(start) to output.format(expiry.time)
    }

    private fun toIsoDate(value: String): String {
        val match = DATE_REGEX.matchEntire(value)
            ?: throw NativeSyncException("INVALID_DATE: Ngày lớp không hợp lệ.")
        val day = match.groupValues[1].toInt()
        val month = match.groupValues[2].toInt()
        val year = match.groupValues[3].toInt()
        val calendar = Calendar.getInstance().apply {
            isLenient = false
            clear()
            set(year, month - 1, day)
        }
        try {
            calendar.time
        } catch (_: Exception) {
            throw NativeSyncException("INVALID_DATE: Ngày lớp không hợp lệ.")
        }
        return "%04d-%02d-%02d".format(Locale.ROOT, year, month, day)
    }

    private fun xorEncode(plain: String, key: String): String {
        val builder = StringBuilder(plain.length)
        plain.forEachIndexed { index, value ->
            builder.append((value.code xor key[index % key.length].code).toChar())
        }
        return Base64.encodeToString(
            builder.toString().toByteArray(StandardCharsets.UTF_8),
            Base64.NO_WRAP,
        )
    }

    private fun xorDecode(encoded: String, key: String): String {
        val cipher = String(
            Base64.decode(encoded, Base64.DEFAULT),
            StandardCharsets.UTF_8,
        )
        val builder = StringBuilder(cipher.length)
        cipher.forEachIndexed { index, value ->
            builder.append((value.code xor key[index % key.length].code).toChar())
        }
        return builder.toString()
    }

    private fun parseSession(raw: String): Session {
        val value = JSONObject(raw)
        return Session(
            tokenJwt = value.optString("tokenJWT"),
            userId = value.optString("userId"),
            iM = value.optString("iM"),
            appId = value.optString("appId"),
            functionId = value.optString("strChucNangId"),
            cookie = value.optString("cookie"),
            displayName = value.optString("name"),
        )
    }

    private fun requireSession() {
        if (
            session.tokenJwt.isBlank() ||
            session.userId.isBlank() ||
            session.iM.isBlank() ||
            session.appId.isBlank() ||
            session.functionId.isBlank()
        ) {
            throw NativeSyncException(
                "SESSION_EXPIRED: Chưa có native session. Hãy mở app và đồng bộ lại.",
            )
        }
    }

    private class NativeSyncException(message: String) : Exception(message)

    private companion object {
        const val ROOT = "https://qldtbeta.phenikaa-uni.edu.vn"
        const val ACTION_SEMESTERS = "DKH_ThongTin_MH/DSA4FSkuKAYoIC8FIC8mCjgCIA8pIC8P"
        const val FUNC_SEMESTERS = "pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan"
        const val ACTION_PLANS = "DKH_ThongTin_MH/DSA4BRIKJAkuICIpBSAvJgo4AiAPKSAv"
        const val FUNC_PLANS = "pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan"
        const val ACTION_SUBJECTS = "DKH_Chung_MH/DSA4CiQ1EDQgBSAvJgo4DS4xCS4iESkgLwPP"
        const val FUNC_SUBJECTS = "pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan"
        const val ACTION_SCHEDULE = "SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv"
        const val FUNC_SCHEDULE = "pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan"
        val SEMESTER_REGEX = Regex("^(\\d{4})_(\\d{4})_(\\d+)$")
        val DATE_REGEX = Regex("^(\\d{2})/(\\d{2})/(\\d{4})$")
    }
}
