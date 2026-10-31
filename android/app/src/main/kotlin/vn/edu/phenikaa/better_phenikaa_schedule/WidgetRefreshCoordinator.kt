package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/** Resets every widget to the device's current local day and refreshes its data. */
internal object WidgetRefreshCoordinator {
    fun refreshWidget2TimeTheme(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        manager.getAppWidgetIds(ComponentName(context, Widget2Provider::class.java))
            .forEach { id ->
                WidgetRenderDispatcher.render(context, manager,
                    WidgetRenderRequest(WidgetSurface.WIDGET2, id, fadeContent = true))
            }
    }

    fun manualRefresh(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        val smallIds = manager.getAppWidgetIds(
            ComponentName(appContext, ScheduleWidgetProvider::class.java),
        )
        val overviewIds = manager.getAppWidgetIds(
            ComponentName(appContext, OverviewWidgetProvider::class.java),
        )
        ScheduleWidgetProvider().restoreDisplay(appContext, manager, smallIds)
        OverviewWidgetProvider().restoreDisplay(appContext, manager, overviewIds)
    }

    fun refreshData(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        val smallIds = manager.getAppWidgetIds(
            ComponentName(appContext, ScheduleWidgetProvider::class.java),
        )
        val overviewIds = manager.getAppWidgetIds(
            ComponentName(appContext, OverviewWidgetProvider::class.java),
        )
        val data = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        ScheduleWidgetProvider().onUpdate(appContext, manager, smallIds, data)
        OverviewWidgetProvider().onUpdate(appContext, manager, overviewIds, data)
    }

    fun refreshOverview(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, OverviewWidgetProvider::class.java))
        val data = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        OverviewWidgetProvider().onUpdate(context, manager, ids, data)
    }

    fun refreshToday(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        val component = ComponentName(appContext, ScheduleWidgetProvider::class.java)
        val widgetIds = manager.getAppWidgetIds(component)
        val overviewIds = manager.getAppWidgetIds(
            ComponentName(appContext, OverviewWidgetProvider::class.java),
        )
        if (widgetIds.isEmpty() && overviewIds.isEmpty()) return

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
        (widgetIds + overviewIds).forEach { widgetId ->
            selectionEditor
                .remove(ScheduleWidgetProvider.selectedDateKey(widgetId))
                .putBoolean(ScheduleWidgetProvider.resetChildKey(widgetId), true)
            visibleEditor.remove(visiblePositionKey(widgetId))
        }
        selectionEditor.commit()
        visibleEditor.apply()

        if (widgetIds.isNotEmpty()) manager.notifyAppWidgetViewDataChanged(widgetIds, R.id.widget_list)
        val widgetData = appContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        ScheduleWidgetProvider().onUpdate(appContext, manager, widgetIds, widgetData)
        // A date broadcast may end the process immediately after onReceive returns.
        // Render today's overview synchronously instead of leaving its fade on a Handler.
        OverviewWidgetProvider().restoreDisplay(appContext, manager, overviewIds)
    }
}
