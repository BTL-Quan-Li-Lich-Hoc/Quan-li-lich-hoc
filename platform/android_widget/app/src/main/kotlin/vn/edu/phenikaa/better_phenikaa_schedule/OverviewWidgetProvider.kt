package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class OverviewWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            render(context, appWidgetManager, widgetId, widgetData)
        }
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.overview_widget)
        val today = dayKey(Date())
        val items = readItems(widgetData, today)
        val now = isoNow()
        val visibleItems = ArrayList<JSONObject>()
        for (index in 0 until items.length()) {
            val item = items.optJSONObject(index) ?: continue
            val endAt = item.optString("endAt")
            if (endAt.isBlank() || endAt >= now) {
                visibleItems.add(item)
            }
        }

        views.setTextViewText(
            R.id.overview_title,
            "Hôm nay • ${displayDate(today)}",
        )

        val rows = intArrayOf(
            R.id.overview_row_1,
            R.id.overview_row_2,
            R.id.overview_row_3,
            R.id.overview_row_4,
        )
        val subjects = intArrayOf(
            R.id.overview_subject_1,
            R.id.overview_subject_2,
            R.id.overview_subject_3,
            R.id.overview_subject_4,
        )
        val details = intArrayOf(
            R.id.overview_detail_1,
            R.id.overview_detail_2,
            R.id.overview_detail_3,
            R.id.overview_detail_4,
        )

        rows.indices.forEach { index ->
            val item = visibleItems.getOrNull(index)
            if (item == null) {
                views.setViewVisibility(rows[index], View.GONE)
            } else {
                views.setViewVisibility(rows[index], View.VISIBLE)
                views.setTextViewText(
                    subjects[index],
                    item.optString("subjectName").ifBlank { "Lịch học" },
                )
                val detail = listOf(
                    item.optString("time"),
                    item.optString("room"),
                ).filter(String::isNotBlank).joinToString(" • ")
                views.setTextViewText(details[index], detail)
            }
        }

        val empty = if (items.length() == 0) {
            "Không có lịch học hôm nay"
        } else if (visibleItems.isEmpty()) {
            "Hôm nay đã hết lịch học"
        } else {
            ""
        }
        views.setViewVisibility(
            R.id.overview_empty,
            if (empty.isEmpty()) View.GONE else View.VISIBLE,
        )
        views.setTextViewText(R.id.overview_empty, empty)

        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val openApp = PendingIntent.getActivity(
                context,
                widgetId + OPEN_APP_REQUEST_BASE,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.overview_root, openApp)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun readItems(widgetData: SharedPreferences, dateKey: String): JSONArray {
        val raw = widgetData.getString(KEY_OVERVIEW_TIMELINE, "{}").orEmpty()
        return runCatching {
            JSONObject(raw).optJSONArray(dateKey) ?: JSONArray()
        }.getOrDefault(JSONArray())
    }

    private fun dayKey(date: Date): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)

    private fun displayDate(value: String): String {
        val date = runCatching {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(value)
        }.getOrNull() ?: return value
        return SimpleDateFormat("dd/MM", Locale("vi", "VN")).format(date)
    }

    private fun isoNow(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())

    companion object {
        private const val KEY_OVERVIEW_TIMELINE = "widgetOverviewTimeline"
        private const val OPEN_APP_REQUEST_BASE = 50_000
    }
}
