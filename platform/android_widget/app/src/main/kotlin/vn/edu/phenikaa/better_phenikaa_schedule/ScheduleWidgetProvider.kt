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

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val dayKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val timeline = runCatching {
            JSONObject(widgetData.getString("widgetTimeline", "{}") ?: "{}")
        }.getOrDefault(JSONObject())
        val entry = timeline.optJSONObject(dayKey)
        val subject = entry?.optString("subjectName").orEmpty()
            .ifBlank { "Chưa có lịch học" }
        val showRoom = widgetData.getBoolean("showRoom", true)
        val showTime = widgetData.getBoolean("showTime", true)
        val details = buildList {
            if (showTime) {
                entry?.optString("time")?.takeIf(String::isNotBlank)?.let(::add)
            }
            if (showRoom) {
                entry?.optString("room")?.takeIf(String::isNotBlank)?.let(::add)
            }
        }.joinToString(" • ").ifBlank {
            if (entry == null) "Mở ứng dụng để cập nhật" else ""
        }
        val showDate = widgetData.getBoolean("showDateControls", true)
        val dateLabel = if (showDate) {
            SimpleDateFormat("EEE, dd/MM", Locale("vi", "VN")).format(Date())
        } else {
            ""
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)
            views.setTextViewText(R.id.widget_date, dateLabel)
            views.setViewVisibility(
                R.id.widget_date,
                if (dateLabel.isBlank()) View.GONE else View.VISIBLE,
            )
            views.setTextViewText(R.id.widget_subject, subject)
            views.setTextViewText(R.id.widget_details, details)
            views.setViewVisibility(
                R.id.widget_details,
                if (details.isBlank()) View.GONE else View.VISIBLE,
            )
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
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
