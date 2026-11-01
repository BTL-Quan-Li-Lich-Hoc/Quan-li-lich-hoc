package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** One native reader for the normalized, app-local widget contract. */
internal object WidgetSnapshotStore {
    fun read(context: Context, widgetId: Int): WidgetCollection {
        val preferences = context.getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
        val normalized = preferences.getString(WIDGET_SNAPSHOT_KEY, null)
        val legacy = preferences.getString(APP_SNAPSHOT_KEY, null)
        val raw = normalized ?: legacy ?: return WidgetCollection.empty()
        val usesLegacyContract = normalized == null

        return runCatching {
            val today = SimpleDateFormat(DATE_PATTERN, Locale.US).format(Date())
            val now = SimpleDateFormat(DATE_TIME_PATTERN, Locale.US).format(Date())
            val selectedDate = selectedDate(context, widgetId, today)
            val root = JSONObject(raw)
            val records = if (usesLegacyContract) {
                root.optJSONArray("records")
            } else {
                root.optJSONArray("classes")
            } ?: JSONArray()
            val items = ArrayList<WidgetClass>(records.length() + 1)

            for (index in 0 until records.length()) {
                val record = records.optJSONObject(index) ?: continue
                if (usesLegacyContract && record.optBoolean("isExam", false)) continue
                parseClass(record)?.let(items::add)
            }

            if (items.none { it.dateKey == selectedDate }) {
                items.add(emptyDay(selectedDate, today))
            }
            WidgetTimeline.arrange(items, selectedDate, today, now)
        }.getOrElse { WidgetCollection.empty() }
    }

    private fun selectedDate(context: Context, widgetId: Int, today: String): String {
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return today
        return context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        ).getString(ScheduleWidgetProvider.selectedDateKey(widgetId), null)
            ?.takeIf(::isIsoDate)
            ?: today
    }

    private fun parseClass(record: JSONObject): WidgetClass? {
        val startAt = record.optString("startAt")
        val endAt = record.optString("endAt")
        if (startAt.length < 16 || endAt.length < 16) return null
        val dateKey = startAt.take(10)
        if (!isIsoDate(dateKey)) return null

        val room = record.optString("room")
        val date = "${dateKey.substring(8, 10)}/${dateKey.substring(5, 7)}"
        val roomAndDate = listOf(room, date).filter(String::isNotBlank).joinToString(" • ")
        val subject = record.optString("subjectName").ifBlank { "Lịch học Phenikaa" }
        return WidgetClass(
            id = record.optString("id").ifBlank { "$startAt|$subject|$room" },
            subject = subject,
            room = roomAndDate,
            time = "${startAt.substring(11, 16)} - ${endAt.substring(11, 16)}",
            startAt = startAt,
            endAt = endAt,
            dateKey = dateKey,
        )
    }

    private fun emptyDay(selectedDate: String, today: String): WidgetClass {
        val displayDate = "${selectedDate.substring(8, 10)}/${selectedDate.substring(5, 7)}"
        return WidgetClass(
            id = "empty-day-$selectedDate",
            subject = "Không có lịch học",
            room = if (selectedDate == today) "Hôm nay • $displayDate" else displayDate,
            time = "",
            startAt = "${selectedDate}T00:00:00",
            endAt = "${selectedDate}T23:59:59",
            dateKey = selectedDate,
        )
    }

    private fun isIsoDate(value: String): Boolean =
        value.length == 10 &&
            value[4] == '-' &&
            value[7] == '-' &&
            value.substring(0, 4).all(Char::isDigit) &&
            value.substring(5, 7).all(Char::isDigit) &&
            value.substring(8, 10).all(Char::isDigit)

    private const val SNAPSHOT_PREFS = "FlutterSharedPreferences"
    private const val WIDGET_SNAPSHOT_KEY = "flutter.better_phenikaa_widget_snapshot_v1"
    private const val APP_SNAPSHOT_KEY = "flutter.better_phenikaa_snapshot_v1"
    private const val DATE_PATTERN = "yyyy-MM-dd"
    private const val DATE_TIME_PATTERN = "yyyy-MM-dd'T'HH:mm:ss"
}

/** Chronological, non-looping timeline shared with native regression tests. */
internal object WidgetTimeline {
    fun arrange(
        sourceItems: List<WidgetClass>,
        selectedDate: String,
        today: String,
        now: String,
    ): WidgetCollection {
        val items = sourceItems.sortedWith(compareBy(WidgetClass::startAt, WidgetClass::id))
        val indexes = items.indices.filter { items[it].dateKey == selectedDate }
        val selectedIndex = if (selectedDate == today) {
            indexes.firstOrNull { items[it].endAt.take(19) >= now }
                ?: indexes.lastOrNull()
                ?: 0
        } else {
            indexes.firstOrNull() ?: 0
        }
        return WidgetCollection(items, selectedIndex)
    }
}

internal data class WidgetCollection(
    val items: List<WidgetClass>,
    val selectedIndex: Int,
) {
    companion object {
        fun empty() = WidgetCollection(emptyList(), 0)
    }
}

internal data class WidgetClass(
    val id: String,
    val subject: String,
    val room: String,
    val time: String,
    val startAt: String,
    val endAt: String,
    val dateKey: String,
) {
    val stableId: Long
        get() = id.hashCode().toLong()
}
