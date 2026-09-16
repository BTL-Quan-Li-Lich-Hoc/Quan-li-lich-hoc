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
import java.util.Calendar
import java.util.Date
import java.util.Locale

class ScheduleWidgetProvider : HomeWidgetProvider() {
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

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PREVIOUS_DAY,
            ACTION_NEXT_DAY,
            ACTION_TODAY -> {
                val widgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID,
                )
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    when (intent.action) {
                        ACTION_PREVIOUS_DAY -> shiftSelectedDate(context, widgetId, -1)
                        ACTION_NEXT_DAY -> shiftSelectedDate(context, widgetId, 1)
                        ACTION_TODAY -> setSelectedDate(context, widgetId, todayKey())
                    }
                    requestUpdate(context, widgetId)
                }
                return
            }
        }
        super.onReceive(context, intent)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val editor = context
            .getSharedPreferences(SELECTION_PREFS, Context.MODE_PRIVATE)
            .edit()
        appWidgetIds.forEach { widgetId -> editor.remove(selectionKey(widgetId)) }
        editor.apply()
        super.onDeleted(context, appWidgetIds)
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget)
        val selectedDate = selectedDate(context, widgetId)
        val item = readItem(widgetData, selectedDate)

        views.setTextViewText(R.id.widget_date, displayDate(selectedDate))
        views.setTextViewText(
            R.id.widget_subject,
            item?.optString("subjectName").orEmpty().ifBlank { "Không có lịch học" },
        )
        views.setTextViewText(R.id.widget_room, item?.optString("room").orEmpty())
        views.setTextViewText(R.id.widget_time, item?.optString("time").orEmpty())

        val showRoom = widgetData.getBoolean(KEY_SHOW_ROOM, true)
        val showTime = widgetData.getBoolean(KEY_SHOW_TIME, true)
        val showDateControls = widgetData.getBoolean(KEY_SHOW_DATE_CONTROLS, true)
        views.setViewVisibility(R.id.widget_room, if (showRoom) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.widget_time, if (showTime) View.VISIBLE else View.GONE)
        views.setViewVisibility(
            R.id.widget_date_controls,
            if (showDateControls) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(
            R.id.widget_previous,
            actionIntent(context, widgetId, ACTION_PREVIOUS_DAY, 1),
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            actionIntent(context, widgetId, ACTION_NEXT_DAY, 2),
        )
        views.setOnClickPendingIntent(
            R.id.widget_date,
            actionIntent(context, widgetId, ACTION_TODAY, 3),
        )

        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val openApp = PendingIntent.getActivity(
                context,
                widgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_content, openApp)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun readItem(widgetData: SharedPreferences, dateKey: String): JSONObject? {
        val raw = widgetData.getString(KEY_TIMELINE, "{}").orEmpty()
        return runCatching { JSONObject(raw).optJSONObject(dateKey) }.getOrNull()
    }

    private fun actionIntent(
        context: Context,
        widgetId: Int,
        action: String,
        requestOffset: Int,
    ): PendingIntent {
        val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId * 10 + requestOffset,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun selectedDate(context: Context, widgetId: Int): String {
        val prefs = context.getSharedPreferences(SELECTION_PREFS, Context.MODE_PRIVATE)
        return prefs.getString(selectionKey(widgetId), null) ?: todayKey()
    }

    private fun setSelectedDate(context: Context, widgetId: Int, value: String) {
        context.getSharedPreferences(SELECTION_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(selectionKey(widgetId), value)
            .apply()
    }

    private fun shiftSelectedDate(context: Context, widgetId: Int, days: Int) {
        val formatter = keyFormatter()
        val current = selectedDate(context, widgetId)
        val calendar = Calendar.getInstance().apply {
            time = runCatching { formatter.parse(current) }.getOrNull() ?: Date()
            add(Calendar.DAY_OF_MONTH, days)
        }
        setSelectedDate(context, widgetId, formatter.format(calendar.time))
    }

    private fun requestUpdate(context: Context, widgetId: Int) {
        val update = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
        }
        context.sendBroadcast(update)
    }

    private fun todayKey(): String = keyFormatter().format(Calendar.getInstance().time)

    private fun displayDate(value: String): String {
        val source = keyFormatter()
        val date = runCatching { source.parse(value) }.getOrNull() ?: return value
        return SimpleDateFormat("dd/MM", Locale("vi", "VN")).format(date)
    }

    private fun keyFormatter(): SimpleDateFormat {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
    }

    private fun selectionKey(widgetId: Int): String = "selected_date_$widgetId"

    companion object {
        private const val KEY_TIMELINE = "widgetTimeline"
        private const val KEY_SHOW_ROOM = "showRoom"
        private const val KEY_SHOW_TIME = "showTime"
        private const val KEY_SHOW_DATE_CONTROLS = "showDateControls"
        private const val SELECTION_PREFS = "schedule_widget_selection"
        private const val ACTION_PREVIOUS_DAY =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET_PREVIOUS_DAY"
        private const val ACTION_NEXT_DAY =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET_NEXT_DAY"
        private const val ACTION_TODAY =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET_TODAY"
    }
}
