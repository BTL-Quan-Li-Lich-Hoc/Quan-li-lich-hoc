package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/** Resets every widget to the device's current local day and refreshes its data. */
internal object WidgetRefreshCoordinator {
    fun refreshToday(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        val component = ComponentName(appContext, ScheduleWidgetProvider::class.java)
        val widgetIds = manager.getAppWidgetIds(component)
        if (widgetIds.isEmpty()) return

        val selection = appContext.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        )
        val visible = appContext.getSharedPreferences(
            WIDGET_VISIBLE_POSITION_PREFS,
            Context.MODE_PRIVATE,
        )
        val selectionEditor = selection.edit()
        val visibleEditor = visible.edit()
        widgetIds.forEach { widgetId ->
            selectionEditor
                .remove(ScheduleWidgetProvider.selectedDateKey(widgetId))
                .putBoolean(ScheduleWidgetProvider.resetChildKey(widgetId), true)
            visibleEditor.remove(visiblePositionKey(widgetId))
        }
        selectionEditor.commit()
        visibleEditor.apply()

        manager.notifyAppWidgetViewDataChanged(widgetIds, R.id.widget_list)
        val widgetData = appContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        ScheduleWidgetProvider().onUpdate(appContext, manager, widgetIds, widgetData)
    }
}
