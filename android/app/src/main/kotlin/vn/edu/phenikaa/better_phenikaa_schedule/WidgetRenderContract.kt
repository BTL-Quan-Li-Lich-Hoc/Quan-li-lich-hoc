package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.Context

/** The three launcher surfaces share data/sync, but own their visual renderer. */
internal enum class WidgetSurface(val wireName: String) {
    SMALL("small"),
    LARGE("large"),
    WIDGET2("widget2");

    companion object {
        fun fromWireName(value: String?): WidgetSurface =
            entries.firstOrNull { it.wireName == value } ?: SMALL
    }
}

internal data class WidgetRenderRequest(
    val surface: WidgetSurface,
    val widgetId: Int,
    val forceStaticLayer: Boolean = false,
    val fadeContent: Boolean = false,
)

/**
 * One dispatcher produces exactly one widget output per request. It deliberately
 * does not own schedule parsing or synchronization; every branch reads the same
 * [WidgetSnapshotStore] and is refreshed by [WidgetRefreshCoordinator].
 */
internal object WidgetRenderDispatcher {
    fun render(context: Context, manager: AppWidgetManager, request: WidgetRenderRequest) {
        when (request.surface) {
            WidgetSurface.SMALL -> ScheduleWidgetProvider().renderFromDispatcher(
                context,
                manager,
                request.widgetId,
            )
            WidgetSurface.LARGE -> OverviewWidgetProvider().renderFromDispatcher(
                context,
                manager,
                request.widgetId,
            )
            WidgetSurface.WIDGET2 -> Widget2Provider().renderFromDispatcher(
                context,
                manager,
                request.widgetId,
                request.forceStaticLayer,
                request.fadeContent,
            )
        }
    }
}
