package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
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
        val dayKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val timeline = runCatching {
            JSONObject(widgetData.getString("widgetOverviewTimeline", "{}") ?: "{}")
        }.getOrDefault(JSONObject())
        val entries = timeline.optJSONArray(dayKey)
        val showRoom = widgetData.getBoolean("showRoom", true)
        val showTime = widgetData.getBoolean("showTime", true)
        val showDate = widgetData.getBoolean("showDateControls", true)
        val rowIds = intArrayOf(
            R.id.widget_row_1,
            R.id.widget_row_2,
            R.id.widget_row_3,
            R.id.widget_row_4,
        )
        val dateLabel = if (showDate) {
            SimpleDateFormat("EEEE, dd/MM/yyyy", Locale("vi", "VN")).format(Date())
        } else {
            ""
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.overview_widget)
            views.setTextViewText(R.id.widget_date, dateLabel)
            views.setViewVisibility(
                R.id.widget_date,
                if (dateLabel.isBlank()) View.GONE else View.VISIBLE,
            )
            val count = entries?.length() ?: 0
            views.setViewVisibility(
                R.id.widget_empty,
                if (count == 0) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(R.id.widget_empty, "Không có buổi học trong ngày")

            rowIds.forEachIndexed { index, viewId ->
                val entry = entries?.optJSONObject(index)
                if (entry == null) {
                    views.setViewVisibility(viewId, View.GONE)
                } else {
                    val time = if (showTime) {
                        entry.optString("time").takeIf(String::isNotBlank)
                    } else {
                        null
                    }
                    val room = if (showRoom) {
                        entry.optString("room").takeIf(String::isNotBlank)
                    } else {
                        null
                    }
                    val subject = entry.optString("subjectName")
                    val detail = listOfNotNull(time, room).joinToString(" • ")
                    views.setTextViewText(
                        viewId,
                        if (detail.isBlank()) subject else "$subject\n$detail",
                    )
                    views.setViewVisibility(viewId, View.VISIBLE)
                }
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                launchIntent(context, widgetId),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launchIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId + 10000,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
